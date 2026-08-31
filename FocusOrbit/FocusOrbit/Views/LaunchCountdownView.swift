import SwiftUI
import UIKit
import SwiftData

struct LaunchCountdownView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var context
    let destination: Destination
    let settings: AppSettings?
    let completion: @MainActor () -> Void
    @State private var count = 5
    @State private var phase: LaunchVisualPhase = .standby
    @State private var phaseStart = Date()
    @State private var isCountdownActive = false
    @State private var phaseDuration: TimeInterval = 9
    @State private var orbitDuration: TimeInterval = 8.1
    @State private var throttlePosition: Double = 0
    @State private var isThrottleArmed = false

    init(router: AppRouter, mission: Mission, settings: AppSettings?) {
        destination = mission.destination
        self.settings = settings
        completion = { router.show(.flight) }
    }

    init(destination: Destination, settings: AppSettings?, completion: @escaping @MainActor () -> Void) {
        self.destination = destination
        self.settings = settings
        self.completion = completion
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 / 12 : 1 / 60)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(phaseStart)
            let progress = phaseProgress(elapsed)
            ZStack {
                LaunchVisualScene(
                    phase: phase,
                    phaseProgress: progress,
                    destination: destination,
                    throttlePosition: throttlePosition
                )
                VStack {
                    HStack {
                        launchChip(statusLabel, tint: .white)
                        Spacer()
                        launchChip(destination.englishName, tint: destination.accent)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    Spacer()
                    if phase == .standby && isThrottleArmed {
                        VStack(spacing: 7) {
                            Text("ENGINE CONTROL").font(.caption.weight(.semibold)).tracking(3).foregroundStyle(.cyan.opacity(0.9))
                            Text(String(localized: "launch.lower_lever", defaultValue: "レバーを下げて発進")).font(.title3.weight(.bold)).foregroundStyle(.white)
                            Text(String(localized: "launch.drag_slowly", defaultValue: "下までゆっくりドラッグしてください")).font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.86))
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 13)
                        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.2)))
                        .shadow(color: .black.opacity(0.8), radius: 14, y: 5)
                        .padding(.bottom, 238)
                    } else if phase == .standby && isCountdownActive {
                        VStack(spacing: 10) {
                            Text("LAUNCH IN").font(.caption).tracking(4).foregroundStyle(AppTheme.secondary)
                            Text(String(localized: "launch.count_value", defaultValue: "\(count)")).font(.system(size: 104, weight: .ultraLight, design: .rounded)).monospacedDigit().contentTransition(.numericText())
                            Text(String(localized: "launch.keep_position", defaultValue: "姿勢を固定し、カウントダウンを継続"))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.72))
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(.black.opacity(0.40), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.08)))
                        .padding(.bottom, 145)
                    } else if phase == .standby {
                        VStack(spacing: 7) {
                            Text("CABIN SECURE").font(.system(size: 25, weight: .light, design: .rounded)).tracking(2)
                            Text(String(localized: "launch.checking_ready", defaultValue: "発射準備を確認しています")).font(.caption).tracking(1.4).foregroundStyle(AppTheme.secondary)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(.black.opacity(0.40), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.08)))
                        .padding(.bottom, 145)
                    } else {
                        VStack(spacing: 5) {
                            Text(phaseTitle(progress)).font(.system(size: 28, weight: .light, design: .rounded)).tracking(2)
                            Text(phaseSubtitle(progress)).font(.caption).tracking(1.4).foregroundStyle(AppTheme.secondary)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(.black.opacity(0.40), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.08)))
                        .padding(.bottom, 145)
                        .transition(.opacity)
                    }
                }

                if isThrottleArmed {
                    GeometryReader { proxy in
                        throttleGestureArea(size: proxy.size)
                    }
                }
            }
        }
        .task {
            if settings?.hasCompletedFullLaunch == true && settings?.shortenLaunchSequence == true {
                await runShortSequence()
            } else {
                await runFullSequence()
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .statusBarHidden(true)
    }

    private func runFullSequence() async {
        let voiceEnabled = settings?.voiceAnnouncementsEnabled ?? true
        AnnouncementService.shared.speak(String(localized: "launch.announcement.prelaunch", defaultValue: "発射準備が整いました。シートに深く腰掛け、そのままお待ちください。"), clipName: "cabin_prelaunch", enabled: voiceEnabled)
        if voiceEnabled { try? await Task.sleep(for: .seconds(7.2)) }
        withAnimation(.easeIn(duration: 0.25)) { isCountdownActive = true }
        for value in stride(from: 5, through: 1, by: -1) { withAnimation { count = value }; try? await Task.sleep(for: .seconds(1)) }
        await waitForThrottlePull()
        phaseStart = .now; phase = .ignition
        MissionHaptics.launchSequence(enabled: settings?.hapticsEnabled ?? true, reduceMotion: reduceMotion)
        AudioService.shared.startLaunchRumbleIfEnabled(settings?.ambientSoundEnabled ?? true)
        AnnouncementService.shared.speak(String(localized: "launch.announcement.liftoff", defaultValue: "メインエンジン点火。離床します。"), clipName: "cabin_liftoff", chime: false, enabled: voiceEnabled)
        try? await Task.sleep(for: .seconds(2.6))
        phaseStart = .now; phase = .ascent
        MissionHaptics.ascentBurst(enabled: settings?.hapticsEnabled ?? true, reduceMotion: reduceMotion)
        try? await Task.sleep(for: .seconds(9.0))
        phaseStart = .now; phase = .orbit
        MissionHaptics.completed(enabled: settings?.hapticsEnabled ?? true)
        AnnouncementService.shared.speak(String(localized: "launch.announcement.orbit", defaultValue: "地球周回軌道への投入を確認しました。船内は通常航行へ移行します。"), clipName: "cabin_orbit_inserted", enabled: voiceEnabled)
        try? await Task.sleep(for: .seconds(voiceEnabled ? 8.1 : 2.2))
        AudioService.shared.stop()
        settings?.hasCompletedFullLaunch = true
        try? context.save()
        completion()
    }

    private func runShortSequence() async {
        count = 3
        isCountdownActive = true
        for value in stride(from: 3, through: 1, by: -1) {
            withAnimation { count = value }
            try? await Task.sleep(for: .seconds(1))
        }
        await waitForThrottlePull()
        phaseDuration = 7.5
        orbitDuration = 3.2
        phaseStart = .now
        phase = .ignition
        MissionHaptics.launchSequence(enabled: settings?.hapticsEnabled ?? true, reduceMotion: reduceMotion)
        AudioService.shared.startLaunchRumbleIfEnabled(settings?.ambientSoundEnabled ?? true)
        AnnouncementService.shared.speak(String(localized: "launch.announcement.short_liftoff", defaultValue: "離床します。自動航行へ移行いたします。"), clipName: "cabin_liftoff", chime: false, enabled: settings?.voiceAnnouncementsEnabled ?? true)
        try? await Task.sleep(for: .seconds(2.6))
        phaseStart = .now
        phase = .ascent
        MissionHaptics.ascentBurst(enabled: settings?.hapticsEnabled ?? true, reduceMotion: reduceMotion)
        try? await Task.sleep(for: .seconds(phaseDuration))
        phaseStart = .now
        phase = .orbit
        AnnouncementService.shared.speak(String(localized: "launch.announcement.short_orbit", defaultValue: "地球周回軌道へ投入しました。通常航行へ移行します。"), clipName: "cabin_orbit_inserted", enabled: settings?.voiceAnnouncementsEnabled ?? true)
        try? await Task.sleep(for: .seconds(orbitDuration))
        AudioService.shared.stop()
        completion()
    }

    private func throttleGestureArea(size: CGSize) -> some View {
        Color.clear
            .frame(width: 170, height: 230)
            .contentShape(Rectangle())
            .position(x: size.width * 0.5, y: size.height * 0.79)
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        throttlePosition = min(max(value.translation.height / 118, 0), 1)
                    }
                    .onEnded { _ in
                        if throttlePosition >= 0.88 {
                            withAnimation(.easeOut(duration: 0.14)) { throttlePosition = 1 }
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1)
                        } else {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) { throttlePosition = 0 }
                        }
                    }
            )
            .accessibilityLabel(String(localized: "launch.throttle_label", defaultValue: "発射レバー"))
            .accessibilityHint(String(localized: "launch.throttle_hint", defaultValue: "下までドラッグすると発進します"))
            .accessibilityValue(String(localized: "launch.throttle_value", defaultValue: "\(Int(throttlePosition * 100))パーセント"))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: throttlePosition = min(throttlePosition + 0.2, 1)
                case .decrement: throttlePosition = max(throttlePosition - 0.2, 0)
                @unknown default: break
                }
            }
    }

    private func waitForThrottlePull() async {
        isCountdownActive = false
        isThrottleArmed = true
        while throttlePosition < 0.995, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(40))
        }
        isThrottleArmed = false
    }
    private func phaseProgress(_ elapsed: TimeInterval) -> Double {
        switch phase { case .standby: 0; case .ignition: min(elapsed / 2.6, 1); case .ascent: min(elapsed / phaseDuration, 1); case .orbit: min(elapsed / orbitDuration, 1) }
    }
    private var statusLabel: String { switch phase { case .standby: "LAUNCH SEQUENCE"; case .ignition: "MAIN ENGINE IGNITION"; case .ascent: "ASCENT"; case .orbit: "ORBITAL INSERTION" } }
    private func phaseTitle(_ progress: Double) -> String {
        switch phase {
        case .standby: ""
        case .ignition: "IGNITION"
        case .ascent: progress < 0.36 ? "LIFTOFF" : progress < 0.74 ? "ASCENT" : "ATMOSPHERE EXIT"
        case .orbit: "ORBIT ACHIEVED"
        }
    }
    private func phaseSubtitle(_ progress: Double) -> String {
        switch phase {
        case .standby: ""
        case .ignition: LocalizedRuntime.text(ja: "ホールドダウン解除準備", en: "Preparing hold-down release")
        case .ascent:
            progress < 0.36
                ? LocalizedRuntime.text(ja: "発射塔を離れています", en: "Clearing the launch tower")
                : progress < 0.74
                    ? LocalizedRuntime.text(ja: "大気圏を上昇中", en: "Ascending through the atmosphere")
                    : LocalizedRuntime.text(ja: "地球の縁を確認、軌道投入へ移行", en: "Earth limb confirmed, transitioning to orbital insertion")
        case .orbit: LocalizedRuntime.text(ja: "地球周回軌道への投入を確認", en: "Orbital insertion confirmed")
        }
    }

    private func launchChip(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .tracking(1.1)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.black.opacity(0.38), in: Capsule())
            .overlay(Capsule().stroke(tint.opacity(tint == .white ? 0.10 : 0.22)))
            .foregroundStyle(tint == .white ? .white.opacity(0.78) : tint)
    }
}
