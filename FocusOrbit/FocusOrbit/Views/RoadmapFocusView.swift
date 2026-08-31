import SwiftData
import SwiftUI
import UIKit

struct RoadmapFocusView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    let router: AppRouter
    let records: [RoadmapFocusRecord]
    let crewName: String
    let settings: AppSettings?
    let sessionManager: RoadmapSessionManager
    @State private var showEndConfirmation = false
    @State private var activeTransition: RoadmapTransition?
    @State private var transitionStartedAt = Date()
    @State private var transitionSequenceRunning = false
    @State private var showDepartureAuthorization = false
    @State private var departureAuthorized = false
    @State private var departureThrottleArmed = false
    @State private var departureThrottlePosition: Double = 0

    private var historicalSeconds: TimeInterval { RoadmapStorageService.totalSeconds(records) }
    private var progress: RoadmapProgress {
        RoadmapProgress(totalSeconds: historicalSeconds + sessionManager.elapsedSeconds)
    }
    private var phase: MissionPhase {
        MissionPhase.resolve(progress: progress.legFraction, destination: progress.target, completed: progress.isComplete)
    }
    private var displayMode: FocusDisplayMode { settings?.flightDisplayMode ?? .cockpit }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                FlightSceneView(
                    destination: progress.target,
                    origin: progress.origin,
                    fallbackProgress: progress.legFraction,
                    scheduledEndAt: nil,
                    totalSeconds: progress.leg.requiredSeconds,
                    phase: phase,
                    displayMode: displayMode,
                    isPaused: sessionManager.isPaused,
                    isActive: scenePhase == .active,
                    darkRoomMode: settings?.darkRoomModeEnabled ?? false
                )

                VStack(spacing: 0) {
                    header(safeArea: proxy.safeAreaInsets)
                    Spacer()
                    if sessionManager.isPaused {
                        pausePanel(bottomInset: proxy.safeAreaInsets.bottom)
                    } else {
                        focusHUD(bottomInset: proxy.safeAreaInsets.bottom)
                    }
                }

                if let activeTransition {
                    RoadmapTransitionScene(
                        transition: activeTransition,
                        startedAt: transitionStartedAt,
                        displayMode: displayMode
                    )
                    .transition(.opacity)
                    .zIndex(10)
                }

                if departureThrottleArmed {
                    RoadmapDepartureThrottleControl(position: $departureThrottlePosition)
                        .zIndex(11)
                }

                if showDepartureAuthorization {
                    SpaceBackground(accent: progress.target.accent)
                        .ignoresSafeArea()
                        .zIndex(12)
                    RoadmapPassView(
                        router: router,
                        progress: progress,
                        crewName: crewName,
                        settings: settings,
                        sessionManager: sessionManager,
                        onCancel: {},
                        onAuthorized: {
                            departureAuthorized = true
                            showDepartureAuthorization = false
                        }
                    )
                    .zIndex(13)
                }
            }
            .ignoresSafeArea()
        }
        .statusBarHidden(true)
        .confirmationDialog(LocalizedRuntime.text(ja: "ロードマップ集中を終了しますか？", en: "End roadmap focus?"), isPresented: $showEndConfirmation, titleVisibility: .visible) {
            Button(LocalizedRuntime.text(ja: "集中を続ける", en: "Continue Focus"), role: .cancel) {}
            Button(LocalizedRuntime.text(ja: "終了して記録する", en: "End and Save"), role: .destructive) { finish() }
        } message: {
            Text(LocalizedRuntime.text(ja: "ここまでの集中時間をロードマップへ反映します", en: "Your focus time so far will be applied to the roadmap"))
        }
        .task { await playPendingTransitions() }
        .onChange(of: progress.completedDestinationCount) { _, _ in
            Task { await playPendingTransitions() }
        }
        .onChange(of: sessionManager.isPaused) { _, paused in
            if !paused { Task { await playPendingTransitions() } }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await playPendingTransitions() } }
        }
    }

    private func header(safeArea: EdgeInsets) -> some View {
        VStack(spacing: 8) {
            Text(LocalizedRuntime.text(ja: "ロードマップ航行中", en: "Roadmap Flight"))
                .font(.title3.weight(.semibold))
            HStack(spacing: 8) {
                roadmapChip(phase.japaneseTitle, tint: progress.target.accent)
                roadmapChip("\(progress.originName) → \(progress.target.name)", tint: .white)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, max(safeArea.top + 14, 30))
        .shadow(color: .black.opacity(0.9), radius: 10)
    }

    private func focusHUD(bottomInset: CGFloat) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .bottom, spacing: 16) {
                elapsedTime
                Spacer(minLength: 10)
                Button { sessionManager.pauseSession() } label: {
                    Image(systemName: "pause.fill")
                        .font(.title2.weight(.semibold))
                        .frame(width: 62, height: 62)
                        .background(.white.opacity(0.12), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.24)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(LocalizedRuntime.text(ja: "一時停止", en: "Pause"))
            }
            roadmapProgress
            HStack(spacing: 10) {
                routePill(LocalizedRuntime.text(ja: "累計 \(Formatters.hoursMinutes(historicalSeconds + sessionManager.elapsedSeconds))", en: "Total \(Formatters.hoursMinutes(historicalSeconds + sessionManager.elapsedSeconds))"), symbol: "chart.line.uptrend.xyaxis")
                routePill(LocalizedRuntime.text(ja: "残り \(Formatters.hoursMinutes(progress.remainingSeconds))", en: "Remaining \(Formatters.hoursMinutes(progress.remainingSeconds))"), symbol: "location.north.line")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, max(bottomInset, 14))
        .background(
            LinearGradient(
                colors: [Color(red: 0.025, green: 0.045, blue: 0.075).opacity(0.94), .black.opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 25, topTrailingRadius: 25))
    }

    private var elapsedTime: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(LocalizedRuntime.text(ja: "今回の集中時間", en: "Current Focus"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.72))
            Text(Formatters.clock(sessionManager.elapsedSeconds))
                .font(.system(size: 58, weight: .ultraLight, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
    }

    private var roadmapProgress: some View {
        VStack(spacing: 7) {
            HStack {
                Text(phase.japaneseTitle).font(.subheadline.weight(.semibold))
                Spacer()
                Text(String(localized: "common.percent_value", defaultValue: "\(Int(progress.legFraction * 100))%"))
                    .font(.subheadline.monospacedDigit().weight(.semibold))
            }
            ProgressView(value: progress.legFraction)
                .tint(progress.target.accent)
            HStack {
                Text(progress.originName)
                Spacer()
                Text(progress.target.name)
            }
            .font(.caption2)
            .foregroundStyle(AppTheme.secondary)
        }
    }

    private func pausePanel(bottomInset: CGFloat) -> some View {
        VStack(spacing: 16) {
            Text(LocalizedRuntime.text(ja: "一時停止中", en: "Paused")).font(.title2.weight(.semibold))
            Text(Formatters.clock(sessionManager.elapsedSeconds))
                .font(.system(size: 46, weight: .light, design: .rounded))
                .monospacedDigit()
            HStack(spacing: 10) {
                routePill("\(progress.originName) → \(progress.target.name)", symbol: "point.3.connected.trianglepath.dotted")
                routePill(LocalizedRuntime.text(ja: "区間 \(Int(progress.legFraction * 100))%", en: "Leg \(Int(progress.legFraction * 100))%"), symbol: "percent")
            }
            if settings != nil {
                FocusDisplayModePicker(selection: displayModeBinding)
            }
            Button { sessionManager.resumeSession() } label: {
                Label(LocalizedRuntime.text(ja: "集中を再開", en: "Resume Focus"), systemImage: "play.fill")
                    .frame(maxWidth: .infinity, minHeight: OrbitDesign.Size.primaryButtonHeight)
                    .background(AppTheme.navigation, in: RoundedRectangle(cornerRadius: OrbitDesign.Radius.button))
                    .foregroundStyle(.black)
                    .fontWeight(.bold)
            }
            Button(role: .destructive) { showEndConfirmation = true } label: {
                Text(LocalizedRuntime.text(ja: "終了してロードマップへ反映", en: "End and Apply to Roadmap"))
                    .frame(maxWidth: .infinity, minHeight: OrbitDesign.Size.minimumTap)
            }
        }
        .padding(20)
        .padding(.bottom, max(bottomInset, 8))
        .background(.black.opacity(0.88))
        .overlay(alignment: .top) { Rectangle().fill(progress.target.accent.opacity(0.55)).frame(height: 1) }
    }

    private var displayModeBinding: Binding<FocusDisplayMode> {
        Binding(
            get: { displayMode },
            set: { mode in
                settings?.flightDisplayMode = mode
                try? context.save()
            }
        )
    }

    private func finish() {
        guard let completed = sessionManager.finishSession() else { return }
        context.insert(RoadmapFocusRecord(
            id: completed.id,
            startedAt: completed.startedAt,
            completedAt: completed.completedAt,
            focusedSeconds: completed.focusedSeconds,
            pauseCount: completed.pauseCount
        ))
        try? context.save()
        router.show(.roadmap)
    }

    @MainActor
    private func playPendingTransitions() async {
        guard !transitionSequenceRunning,
              sessionManager.isActive,
              !sessionManager.isPaused,
              scenePhase == .active else { return }
        transitionSequenceRunning = true
        defer {
            activeTransition = nil
            transitionSequenceRunning = false
        }

        while true {
            if let pendingIndex = sessionManager.pendingSurfaceDepartureIndex {
                guard RoadmapRoute.legs.indices.contains(pendingIndex) else { return }
                let destination = RoadmapRoute.legs[pendingIndex].destination
                let nextIndex = pendingIndex + 1
                guard RoadmapRoute.legs.indices.contains(nextIndex) else { return }
                let nextDestination = RoadmapRoute.legs[nextIndex].destination
                guard await authorizeDeparture() else { return }
                guard await presentInteractiveDeparture(origin: destination, next: nextDestination) else { return }
                sessionManager.completeSurfaceDepartureCheckpoint()
                continue
            }

            guard sessionManager.acknowledgedDestinationCount < progress.completedDestinationCount else { return }
            let arrivedIndex = sessionManager.acknowledgedDestinationCount
            guard RoadmapRoute.legs.indices.contains(arrivedIndex) else { return }
            let destination = RoadmapRoute.legs[arrivedIndex].destination

            if destination.isSurfaceDestination {
                guard await present(.arrival(destination)) else { return }
                if arrivedIndex < RoadmapRoute.legs.count - 1 {
                    sessionManager.beginSurfaceDepartureCheckpoint(at: arrivedIndex)
                    continue
                }
                sessionManager.acknowledgeDestinations(upTo: arrivedIndex + 1)
            } else {
                if arrivedIndex == RoadmapRoute.legs.count - 1 {
                    guard await present(.arrival(destination)) else { return }
                    sessionManager.acknowledgeDestinations(upTo: arrivedIndex + 1)
                    continue
                }
                let nextDestination = RoadmapRoute.legs[arrivedIndex + 1].destination
                guard await present(.flyby(destination: destination, next: nextDestination)) else { return }
                sessionManager.acknowledgeDestinations(upTo: arrivedIndex + 1)
            }
        }
    }

    @MainActor
    private func present(_ transition: RoadmapTransition) async -> Bool {
        activeTransition = transition
        transitionStartedAt = .now
        announce(transition)
        try? await Task.sleep(for: .seconds(transition.duration))
        guard !Task.isCancelled, scenePhase == .active else {
            activeTransition = nil
            return false
        }
        activeTransition = nil
        return true
    }

    private func announce(_ transition: RoadmapTransition) {
        let enabled = settings?.voiceAnnouncementsEnabled ?? true
        switch transition {
        case let .arrival(destination):
            if destination.isSurfaceDestination {
                let clipName: String? = switch destination {
                case .moon: "cabin_lunar_descent"
                case .mars: "cabin_mars_descent"
                case .pluto: "roadmap_pluto_descent"
                default: nil
                }
                AnnouncementService.shared.speakReplacingQueue(
                    LocalizedRuntime.text(ja: "まもなく\(destination.name)へ着陸します。降下姿勢を維持します。", en: "Approaching \(destination.name) for landing. Maintain descent attitude."),
                    clipName: clipName,
                    chime: false,
                    enabled: enabled
                )
            } else {
                AnnouncementService.shared.speakReplacingQueue(
                    LocalizedRuntime.text(ja: "まもなく\(destination.name)周回軌道へ投入します。減速姿勢を維持します。", en: "Approaching orbital insertion around \(destination.name). Maintain deceleration attitude."),
                    clipName: "cabin_orbit_approach",
                    chime: false,
                    enabled: enabled
                )
            }
        case let .flyby(destination, _):
            let clipName: String? = switch destination {
            case .jupiter: "roadmap_jupiter_flyby"
            case .saturn: "roadmap_saturn_flyby"
            case .uranus: "roadmap_uranus_flyby"
            case .neptune: "roadmap_neptune_flyby"
            default: nil
            }
            AnnouncementService.shared.speakReplacingQueue(
                LocalizedRuntime.text(ja: "\(destination.name)へ最接近します。外層に沿って通過します。", en: "Closest approach to \(destination.name). Passing along the outer edge."),
                clipName: clipName,
                chime: false,
                enabled: enabled
            )
        case .earthLaunch, .departure:
            break
        }
    }

    @MainActor
    private func authorizeDeparture() async -> Bool {
        departureAuthorized = false
        showDepartureAuthorization = true
        while !departureAuthorized, !Task.isCancelled, scenePhase == .active {
            try? await Task.sleep(for: .milliseconds(80))
        }
        showDepartureAuthorization = false
        return departureAuthorized && !Task.isCancelled && scenePhase == .active
    }

    @MainActor
    private func presentInteractiveDeparture(origin: Destination, next: Destination) async -> Bool {
        activeTransition = .departure(origin: origin, next: next)
        transitionStartedAt = .distantFuture
        departureThrottlePosition = 0
        departureThrottleArmed = true
        while departureThrottlePosition < 0.995, !Task.isCancelled, scenePhase == .active {
            try? await Task.sleep(for: .milliseconds(40))
        }
        departureThrottleArmed = false
        guard !Task.isCancelled, scenePhase == .active else {
            activeTransition = nil
            return false
        }
        let immediateLift = UIImpactFeedbackGenerator(style: .heavy)
        immediateLift.prepare()
        immediateLift.impactOccurred(intensity: UIAccessibility.isReduceMotionEnabled ? 0.55 : 1)
        MissionHaptics.launchSequence(
            enabled: settings?.hapticsEnabled ?? true,
            reduceMotion: UIAccessibility.isReduceMotionEnabled
        )
        AudioService.shared.startLaunchRumbleIfEnabled(settings?.ambientSoundEnabled ?? true)
        AnnouncementService.shared.speak(
            LocalizedRuntime.text(ja: "離床します。次の目的地へ向けて上昇します。", en: "Liftoff. Ascending toward the next destination."),
            clipName: "cabin_liftoff",
            chime: false,
            enabled: settings?.voiceAnnouncementsEnabled ?? true
        )
        transitionStartedAt = .now
        try? await Task.sleep(for: .seconds(2.6))
        guard !Task.isCancelled, scenePhase == .active else {
            AudioService.shared.stop()
            activeTransition = nil
            return false
        }
        MissionHaptics.ascentBurst(
            enabled: settings?.hapticsEnabled ?? true,
            reduceMotion: UIAccessibility.isReduceMotionEnabled
        )
        try? await Task.sleep(for: .seconds(max(0, RoadmapTransition.departure(origin: origin, next: next).duration - 2.6)))
        guard !Task.isCancelled, scenePhase == .active else {
            AudioService.shared.stop()
            activeTransition = nil
            return false
        }
        MissionHaptics.completed(enabled: settings?.hapticsEnabled ?? true)
        AnnouncementService.shared.speak(
            LocalizedRuntime.text(ja: "\(origin.name)を離脱しました。通常航行へ移行します。", en: "Departure from \(origin.name) confirmed. Transitioning to normal cruise."),
            clipName: "cabin_orbit_inserted",
            enabled: settings?.voiceAnnouncementsEnabled ?? true
        )
        AudioService.shared.stop()
        activeTransition = nil
        return !Task.isCancelled && scenePhase == .active
    }

    private func roadmapChip(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14), in: Capsule())
            .overlay(Capsule().stroke(tint.opacity(tint == .white ? 0.10 : 0.22)))
            .foregroundStyle(tint == .white ? .white.opacity(0.82) : tint)
    }

    private func routePill(_ title: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
            Text(title)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.white.opacity(0.05), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.08)))
        .foregroundStyle(AppTheme.secondary)
    }
}
