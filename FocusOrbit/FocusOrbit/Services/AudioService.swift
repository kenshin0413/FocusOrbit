import AVFoundation
import Observation

@MainActor
enum CabinAudioSession {
    static func activate() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
    }
}

@MainActor @Observable final class AudioService {
    static let shared = AudioService()
    private var player: AVAudioPlayer?
    private var engine: AVAudioEngine?
    private var ambientNode: AVAudioPlayerNode?
    private var effectEngine: AVAudioEngine?
    private var effectNode: AVAudioPlayerNode?
    private var interruptionTask: Task<Void, Never>?
    private var routeChangeTask: Task<Void, Never>?
    private var playbackRequested = false
    var isPlaying = false

    private init() {
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

    func startIfEnabled(_ enabled: Bool) {
        guard enabled else { playbackRequested = false; return }
        playbackRequested = true
        if player?.isPlaying == true || engine?.isRunning == true { isPlaying = true; return }
        clearPlayback()
        do {
            try CabinAudioSession.activate()
            if let url = Bundle.main.url(forResource: "ambient_engine", withExtension: "m4a") {
                player = try AVAudioPlayer(contentsOf: url); player?.numberOfLoops = -1; player?.volume = 0.22; player?.play()
            } else {
                try startSynthesizedAmbience()
            }
            isPlaying = true
        } catch { isPlaying = false }
    }
    func startLaunchRumbleIfEnabled(_ enabled: Bool) {
        guard enabled else { playbackRequested = false; return }
        playbackRequested = true
        clearPlayback()
        do {
            try CabinAudioSession.activate()
            let sampleRate = 44_100.0
            let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
            let frames = AVAudioFrameCount(sampleRate * 3)
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
            buffer.frameLength = frames
            guard let samples = buffer.floatChannelData?[0] else { return }
            for frame in 0..<Int(frames) {
                let time = Double(frame) / sampleRate
                let pulse = 0.78 + sin(2 * .pi * 1.7 * time) * 0.12
                let rumble = sin(2 * .pi * 31 * time) * 0.12 + sin(2 * .pi * 47 * time) * 0.07 + sin(2 * .pi * 73 * time) * 0.025
                samples[frame] = Float(rumble * pulse)
            }
            let audioEngine = AVAudioEngine(); let node = AVAudioPlayerNode()
            audioEngine.attach(node); audioEngine.connect(node, to: audioEngine.mainMixerNode, format: format)
            audioEngine.mainMixerNode.outputVolume = 0.34
            node.scheduleBuffer(buffer, at: nil, options: .loops)
            try audioEngine.start(); node.play()
            engine = audioEngine; ambientNode = node; isPlaying = true
        } catch { isPlaying = false }
    }

    func playLandingImpactIfEnabled(_ enabled: Bool, dustySurface: Bool) {
        guard enabled else { return }
        effectNode?.stop()
        effectEngine?.stop()
        do {
            try CabinAudioSession.activate()
            let sampleRate = 44_100.0
            let duration = dustySurface ? 1.35 : 0.72
            guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
                  let buffer = AVAudioPCMBuffer(
                    pcmFormat: format,
                    frameCapacity: AVAudioFrameCount(sampleRate * duration)
                  ),
                  let samples = buffer.floatChannelData?[0] else { return }
            buffer.frameLength = buffer.frameCapacity
            var noiseState: UInt32 = 0x5EED1234
            for frame in 0..<Int(buffer.frameLength) {
                let time = Double(frame) / sampleRate
                let thump = sin(2 * .pi * (54 - time * 16) * time) * exp(-time * 8.2) * 0.72
                noiseState = noiseState &* 1_664_525 &+ 1_013_904_223
                let noise = (Double(noiseState) / Double(UInt32.max) * 2 - 1)
                let dustEnvelope = dustySurface && time > 0.07 ? exp(-(time - 0.07) * 2.7) * 0.18 : 0
                samples[frame] = Float(max(-1, min(1, thump + noise * dustEnvelope)))
            }
            let audioEngine = AVAudioEngine()
            let node = AVAudioPlayerNode()
            audioEngine.attach(node)
            audioEngine.connect(node, to: audioEngine.mainMixerNode, format: format)
            audioEngine.mainMixerNode.outputVolume = 0.55
            node.scheduleBuffer(buffer)
            try audioEngine.start()
            node.play()
            effectEngine = audioEngine
            effectNode = node
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(duration + 0.15))
                self?.effectNode?.stop()
                self?.effectEngine?.stop()
                self?.effectNode = nil
                self?.effectEngine = nil
            }
        } catch {
            effectNode = nil
            effectEngine = nil
        }
    }
    private func startSynthesizedAmbience() throws {
        let sampleRate = 44_100.0
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let frames = AVAudioFrameCount(sampleRate * 4)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        guard let samples = buffer.floatChannelData?[0] else { return }
        for frame in 0..<Int(frames) {
            let time = Double(frame) / sampleRate
            let engineHum = sin(2 * .pi * 48 * time) * 0.07 + sin(2 * .pi * 72 * time) * 0.025
            let air = sin(2 * .pi * 137 * time + sin(time * 0.4)) * 0.009
            samples[frame] = Float(engineHum + air)
        }
        let audioEngine = AVAudioEngine(); let node = AVAudioPlayerNode()
        audioEngine.attach(node); audioEngine.connect(node, to: audioEngine.mainMixerNode, format: format)
        audioEngine.mainMixerNode.outputVolume = 0.24
        node.scheduleBuffer(buffer, at: nil, options: .loops); try audioEngine.start(); node.play()
        engine = audioEngine; ambientNode = node
    }
    func stop() {
        playbackRequested = false
        clearPlayback()
    }

    private func clearPlayback() {
        player?.stop(); player = nil; ambientNode?.stop(); engine?.stop(); ambientNode = nil; engine = nil
        isPlaying = false
    }

    private func recoverPlayback() {
        guard playbackRequested else { return }
        do {
            try CabinAudioSession.activate()
            if let player {
                isPlaying = player.play()
                return
            }
            if let engine, let ambientNode {
                if !engine.isRunning { try engine.start() }
                if !ambientNode.isPlaying { ambientNode.play() }
                isPlaying = true
            }
        } catch {
            isPlaying = false
        }
    }
}
