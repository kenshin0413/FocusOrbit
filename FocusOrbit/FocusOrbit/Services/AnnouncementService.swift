import AVFoundation

@MainActor
final class AnnouncementService: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    static let shared = AnnouncementService()

    private struct Announcement {
        let text: String
        let localClipName: String?
        let includesChime: Bool
    }

    private let synthesizer = AVSpeechSynthesizer()
    private var queue: [Announcement] = []
    private var clipPlayer: AVAudioPlayer?
    private var chimeEngine: AVAudioEngine?
    private var chimeNode: AVAudioPlayerNode?
    private var isPreparingSpeech = false
    private var preparationTask: Task<Void, Never>?
    private var interruptionTask: Task<Void, Never>?
    private var routeChangeTask: Task<Void, Never>?
    private var currentAnnouncement: Announcement?

    override private init() {
        super.init()
        synthesizer.delegate = self
        interruptionTask = Task { @MainActor [weak self] in
            for await notification in NotificationCenter.default.notifications(named: AVAudioSession.interruptionNotification) {
                guard let value = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      AVAudioSession.InterruptionType(rawValue: value) == .ended else { continue }
                self?.recoverPlayback()
            }
        }
        routeChangeTask = Task { @MainActor [weak self] in
            for await notification in NotificationCenter.default.notifications(named: AVAudioSession.routeChangeNotification) {
                guard let value = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                      AVAudioSession.RouteChangeReason(rawValue: value) == .oldDeviceUnavailable else { continue }
                self?.recoverPlayback()
            }
        }
    }

    func speak(_ text: String, clipName: String? = nil, chime: Bool = true, enabled: Bool) {
        guard enabled else { return }
        queue.append(Announcement(text: text, localClipName: clipName, includesChime: chime))
        playNextIfNeeded()
    }

    func speakReplacingQueue(_ text: String, clipName: String? = nil, chime: Bool = true, enabled: Bool) {
        guard enabled else { return }
        stop()
        speak(text, clipName: clipName, chime: chime, enabled: true)
    }

    func stop() {
        queue.removeAll()
        preparationTask?.cancel()
        preparationTask = nil
        isPreparingSpeech = false
        clipPlayer?.stop()
        clipPlayer = nil
        currentAnnouncement = nil
        synthesizer.stopSpeaking(at: .immediate)
        stopChime()
    }

    private func playNextIfNeeded() {
        guard !synthesizer.isSpeaking, clipPlayer?.isPlaying != true, !isPreparingSpeech, !queue.isEmpty else { return }
        do { try CabinAudioSession.activate() } catch { return }
        let item = queue.removeFirst()
        currentAnnouncement = item
        if let name = item.localClipName, let url = localClipURL(named: name) {
            prepareLocalClip(url, item: item)
            return
        }

        isPreparingSpeech = true
        if item.includesChime { playCabinChime() }
        preparationTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(item.includesChime ? 940 : 120))
            guard let self, !Task.isCancelled else { return }
            self.isPreparingSpeech = false
            do { try CabinAudioSession.activate() } catch {
                self.queue.insert(item, at: 0)
                self.currentAnnouncement = nil
                return
            }
            let utterance = AVSpeechUtterance(string: item.text)
            utterance.voice = self.bestVoice()
            utterance.rate = 0.48
            utterance.pitchMultiplier = 0.96
            utterance.volume = 0.78
            utterance.preUtteranceDelay = 0.12
            utterance.postUtteranceDelay = 0.44
            self.synthesizer.speak(utterance)
        }
    }

    private func prepareLocalClip(_ url: URL, item: Announcement) {
        isPreparingSpeech = true
        if item.includesChime { playCabinChime() }
        preparationTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(item.includesChime ? 940 : 80))
            guard let self, !Task.isCancelled else { return }
            self.isPreparingSpeech = false
            do {
                try CabinAudioSession.activate()
                let player = try AVAudioPlayer(contentsOf: url)
                player.delegate = self
                player.volume = 0.82
                player.prepareToPlay()
                self.clipPlayer = player
                if !player.play() { throw CocoaError(.fileReadUnknown) }
            } catch {
                self.clipPlayer = nil
                self.currentAnnouncement = nil
                self.queue.insert(Announcement(text: item.text, localClipName: nil, includesChime: false), at: 0)
                self.playNextIfNeeded()
            }
        }
    }

    private func localClipURL(named name: String) -> URL? {
        for candidate in clipCandidates(for: name) {
            if let url = Bundle.main.url(forResource: candidate, withExtension: "m4a")
                ?? Bundle.main.url(forResource: candidate, withExtension: "wav") {
                return url
            }
        }
        return nil
    }

    private func clipCandidates(for baseName: String) -> [String] {
        LocalizedRuntime.isEnglish ? ["\(baseName)2", baseName] : [baseName]
    }

    private func bestVoice() -> AVSpeechSynthesisVoice? {
        if LocalizedRuntime.isEnglish {
            let english = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
            return english.max { voiceScore($0) < voiceScore($1) }
                ?? AVSpeechSynthesisVoice(language: "en-US")
        }

        let japanese = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "ja-JP" }
        return japanese.max { voiceScore($0) < voiceScore($1) }
            ?? AVSpeechSynthesisVoice(language: "ja-JP")
    }

    private func voiceScore(_ voice: AVSpeechSynthesisVoice) -> Int {
        var score = voice.gender == .female ? 50 : 0
        if voice.quality == .premium { score += 120 }
        if voice.quality == .enhanced { score += 90 }
        let naturalFemaleNames = ["kyoko", "o-ren", "siri female", "nanami"]
        let name = voice.name.lowercased()
        if naturalFemaleNames.contains(where: name.contains) { score += 70 }
        let characterNames = ["flo", "grandma", "shelley", "sandy"]
        if characterNames.contains(where: name.contains) { score -= 100 }
        return score
    }

    private func playCabinChime() {
        stopChime()
        try? CabinAudioSession.activate()
        let sampleRate = 44_100.0
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleRate * 0.78)),
              let samples = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = buffer.frameCapacity
        for frame in 0..<Int(buffer.frameLength) {
            let time = Double(frame) / sampleRate
            let first = time < 0.31
            let localTime = first ? time : time - 0.39
            let frequency = first ? 659.25 : 783.99
            let envelope = max(0, min(localTime / 0.018, 1)) * exp(-localTime * 7.5)
            samples[frame] = Float(sin(2 * .pi * frequency * localTime) * envelope * 0.16)
        }
        let engine = AVAudioEngine(); let node = AVAudioPlayerNode()
        engine.attach(node); engine.connect(node, to: engine.mainMixerNode, format: format)
        do { try engine.start(); node.scheduleBuffer(buffer); node.play(); chimeEngine = engine; chimeNode = node } catch { stopChime() }
    }

    private func stopChime() {
        chimeNode?.stop(); chimeEngine?.stop(); chimeNode = nil; chimeEngine = nil
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.currentAnnouncement = nil; self.playNextIfNeeded() }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.clipPlayer = nil; self.currentAnnouncement = nil; self.playNextIfNeeded() }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            let failed = self.currentAnnouncement
            self.clipPlayer = nil
            self.currentAnnouncement = nil
            if let failed {
                self.queue.insert(Announcement(text: failed.text, localClipName: nil, includesChime: false), at: 0)
            }
            self.playNextIfNeeded()
        }
    }

    private func recoverPlayback() {
        try? CabinAudioSession.activate()
        if let clipPlayer, !clipPlayer.isPlaying {
            if !clipPlayer.play() {
                self.clipPlayer = nil
                if let currentAnnouncement {
                    queue.insert(Announcement(text: currentAnnouncement.text, localClipName: nil, includesChime: false), at: 0)
                    self.currentAnnouncement = nil
                }
                playNextIfNeeded()
            }
        } else {
            playNextIfNeeded()
        }
    }
}
