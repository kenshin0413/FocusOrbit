import SwiftUI

enum RoadmapTransition: Equatable {
    case earthLaunch
    case arrival(Destination)
    case departure(origin: Destination, next: Destination)
    case flyby(destination: Destination, next: Destination)

    var duration: TimeInterval {
        switch self {
        case .earthLaunch: 6
        case .arrival: 6
        case .departure: 6
        case .flyby: 7
        }
    }
}

struct RoadmapTransitionScene: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let transition: RoadmapTransition
    let startedAt: Date
    let displayMode: FocusDisplayMode

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 / 15 : 1 / 60)) { timeline in
            let progress = min(max(timeline.date.timeIntervalSince(startedAt) / transition.duration, 0), 1)
            ZStack {
                visual(progress: progress)
                labels(progress: progress)
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func visual(progress: Double) -> some View {
        switch transition {
        case .earthLaunch:
            let resolved = launchPhase(progress)
            LaunchVisualScene(
                phase: resolved.phase,
                phaseProgress: resolved.progress,
                destination: .moon,
                throttlePosition: 1
            )
        case let .arrival(destination):
            ArrivalVisualScene(
                destination: destination,
                progress: MissionVisualGeometry.eased(progress),
                startingFlightProgress: 0.88,
                displayMode: displayMode,
                reduceMotion: reduceMotion
            )
        case let .departure(origin, next):
            let resolved = launchPhase(progress)
            RoadmapDepartureScene(
                origin: origin,
                next: next,
                phase: resolved.phase,
                phaseProgress: resolved.progress,
                displayMode: displayMode,
                reduceMotion: reduceMotion
            )
        case let .flyby(destination, next):
            RoadmapFlybyScene(
                destination: destination,
                next: next,
                progress: progress,
                displayMode: displayMode
            )
        }
    }

    private func labels(progress: Double) -> some View {
        VStack {
            HStack {
                Text(stageLabel)
                    .font(.caption2.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(accent)
                Spacer()
                Text(String(format: "%03d%%", Int(progress * 100)))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(.horizontal, 24)
            .padding(.top, 52)
            Spacer()
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 27, weight: .light, design: .rounded))
                    .tracking(1.5)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 13)
            .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 15))
            .padding(.bottom, 120)
        }
        .shadow(color: .black.opacity(0.9), radius: 10)
    }

    private var title: String {
        switch transition {
        case .earthLaunch: "LIFTOFF"
        case let .arrival(destination):
            destination.isSurfaceDestination ? "FINAL DESCENT" : "ORBITAL INSERTION"
        case .departure: "SURFACE DEPARTURE"
        case .flyby: "GRAVITY ASSIST"
        }
    }

    private var subtitle: String {
        switch transition {
        case .earthLaunch: LocalizedRuntime.text(ja: "地球を離れ、月へ向かいます", en: "Departing Earth for the Moon")
        case let .arrival(destination):
            destination.isSurfaceDestination
                ? LocalizedRuntime.text(ja: "\(destination.name)へ着陸しています", en: "Landing on \(destination.name)")
                : LocalizedRuntime.text(ja: "\(destination.name)周回軌道へ進入しています", en: "Entering orbit around \(destination.name)")
        case let .departure(origin, next): LocalizedRuntime.text(ja: "\(origin.name)を離れ、\(next.name)へ向かいます", en: "Departing \(origin.name) for \(next.name)")
        case let .flyby(destination, next): LocalizedRuntime.text(ja: "\(destination.name)を右回りで通過し、\(next.name)へ向かいます", en: "Passing \(destination.name) starboard side toward \(next.name)")
        }
    }

    private var stageLabel: String {
        switch transition {
        case .earthLaunch: "ROADMAP LAUNCH"
        case .arrival: "ROADMAP ARRIVAL"
        case .departure: "ROADMAP DEPARTURE"
        case .flyby: "ROADMAP FLYBY"
        }
    }

    private var accent: Color {
        switch transition {
        case .earthLaunch: AppTheme.blue
        case let .arrival(destination): destination.accent
        case let .departure(origin, _): origin.accent
        case let .flyby(destination, _): destination.accent
        }
    }

    private func launchPhase(_ progress: Double) -> (phase: LaunchVisualPhase, progress: Double) {
        if progress < 0.22 { return (.ignition, progress / 0.22) }
        if progress < 0.78 { return (.ascent, (progress - 0.22) / 0.56) }
        return (.orbit, (progress - 0.78) / 0.22)
    }
}

#if DEBUG
private enum RoadmapDemoScenario: String, CaseIterable, Identifiable {
    case earthLaunch
    case roadmapScan
    case moonLanding
    case moonCheckpoint
    case marsLanding
    case marsCheckpoint
    case jupiterFlyby
    case saturnFlyby
    case uranusFlyby
    case neptuneFlyby
    case plutoLanding
    case plutoCheckpoint
    case venusFlyby
    case mercuryArrival

    var id: String { rawValue }

    static var configuredDefault: RoadmapDemoScenario {
        guard let rawValue = ProcessInfo.processInfo.environment["FOCUSORBIT_ROADMAP_DEMO_SCENARIO"],
              let scenario = RoadmapDemoScenario(rawValue: rawValue) else {
            return .earthLaunch
        }
        return scenario
    }

    static var startsAtDepartureStage: Bool {
        ProcessInfo.processInfo.environment["FOCUSORBIT_ROADMAP_DEMO_STAGE"] == "departure"
    }

    var title: String {
        switch self {
        case .earthLaunch: "地球離陸"
        case .roadmapScan: "航路スキャン"
        case .moonLanding: "月着陸"
        case .moonCheckpoint: "月スキャン+離陸"
        case .marsLanding: "火星着陸"
        case .marsCheckpoint: "火星スキャン+離陸"
        case .jupiterFlyby: "木星フライバイ"
        case .saturnFlyby: "土星フライバイ"
        case .uranusFlyby: "天王星フライバイ"
        case .neptuneFlyby: "海王星フライバイ"
        case .plutoLanding: "冥王星着陸"
        case .plutoCheckpoint: "冥王星スキャン+離陸"
        case .venusFlyby: "金星到着"
        case .mercuryArrival: "水星フライバイ"
        }
    }
}

struct RoadmapTransitionDemoView: View {
    let router: AppRouter
    @State private var scenario: RoadmapDemoScenario = .configuredDefault
    @State private var startedAt = Date()
    @State private var throttlePosition: Double = 0
    @State private var showCheckpointScan = false
    @State private var checkpointAuthorized = false
    @State private var checkpointDepartureStarted = false
    @State private var checkpointDepartureAnimating = false
    @State private var departureEffectsTask: Task<Void, Never>?
    @State private var demoRouter = AppRouter()
    @State private var demoSessionManager = RoadmapSessionManager(defaults: UserDefaults(suiteName: "preview.roadmap.demo")!)

    private var checkpointDestination: Destination? {
        switch scenario {
        case .moonCheckpoint: .moon
        case .marsCheckpoint: .mars
        case .plutoCheckpoint: .pluto
        default: nil
        }
    }

    private var activeTransition: RoadmapTransition? {
        switch scenario {
        case .earthLaunch: nil
        case .moonLanding: .arrival(.moon)
        case .moonCheckpoint:
            checkpointDepartureStarted ? .departure(origin: .moon, next: .mars) : .arrival(.moon)
        case .marsLanding: .arrival(.mars)
        case .marsCheckpoint:
            checkpointDepartureStarted ? .departure(origin: .mars, next: .jupiter) : .arrival(.mars)
        case .jupiterFlyby: .flyby(destination: .jupiter, next: .saturn)
        case .saturnFlyby: .flyby(destination: .saturn, next: .uranus)
        case .uranusFlyby: .flyby(destination: .uranus, next: .neptune)
        case .neptuneFlyby: .flyby(destination: .neptune, next: .pluto)
        case .plutoLanding: .arrival(.pluto)
        case .plutoCheckpoint:
            checkpointDepartureStarted ? .departure(origin: .pluto, next: .mercury) : .arrival(.pluto)
        case .venusFlyby: .arrival(.venus)
        case .mercuryArrival: .flyby(destination: .mercury, next: .venus)
        case .roadmapScan: nil
        }
    }

    var body: some View {
        ZStack {
            SpaceBackground(accent: previewAccent)
                .ignoresSafeArea()

            if scenario == .earthLaunch {
                LaunchCountdownView(destination: .moon, settings: nil) {}
            } else if let activeTransition {
                RoadmapTransitionScene(
                    transition: activeTransition,
                    startedAt: checkpointDepartureStarted && !checkpointDepartureAnimating ? .distantFuture : startedAt,
                    displayMode: .cockpit
                )
            }

            if showCheckpointScan, let destination = checkpointDestination {
                SpaceBackground(accent: destination.accent)
                    .ignoresSafeArea()
                RoadmapPassView(
                    router: demoRouter,
                    progress: checkpointProgress(for: destination),
                    crewName: "CREW",
                    settings: nil,
                    sessionManager: demoSessionManager,
                    onCancel: { resetScenario(scenario) },
                    onAuthorized: {
                        checkpointAuthorized = true
                        showCheckpointScan = false
                        checkpointDepartureStarted = true
                        throttlePosition = 0
                    }
                )
                .zIndex(20)
            }

            if checkpointDepartureStarted && !checkpointDepartureAnimating {
                RoadmapDepartureThrottleControl(position: $throttlePosition)
                    .zIndex(21)
            }

            VStack(spacing: 14) {
                header
                scenarioPicker
                Spacer()
                if checkpointDestination != nil {
                    checkpointHint
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .statusBarHidden(true)
        .onAppear {
            resetScenario(scenario)
            announceScenarioStart(scenario)
        }
        .onChange(of: scenario) { _, newValue in
            departureEffectsTask?.cancel()
            AudioService.shared.stop()
            resetScenario(newValue)
            announceScenarioStart(newValue)
        }
        .task(id: demoTaskKey) { await runDemoFlow() }
        .onChange(of: throttlePosition) { _, value in
            guard checkpointDepartureStarted, !checkpointDepartureAnimating, value >= 0.995 else { return }
            checkpointDepartureAnimating = true
            announceCheckpointDeparture()
            let immediateLift = UIImpactFeedbackGenerator(style: .heavy)
            immediateLift.prepare()
            immediateLift.impactOccurred(intensity: UIAccessibility.isReduceMotionEnabled ? 0.55 : 1)
            MissionHaptics.launchSequence(enabled: true, reduceMotion: UIAccessibility.isReduceMotionEnabled)
            AudioService.shared.startLaunchRumbleIfEnabled(true)
            departureEffectsTask?.cancel()
            departureEffectsTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.6))
                guard !Task.isCancelled else { return }
                MissionHaptics.ascentBurst(enabled: true, reduceMotion: UIAccessibility.isReduceMotionEnabled)
                try? await Task.sleep(for: .seconds(3.4))
                guard !Task.isCancelled else { return }
                MissionHaptics.completed(enabled: true)
                AudioService.shared.stop()
            }
            startedAt = .now
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(String(localized: "roadmap_transition.demo_title", defaultValue: "ロードマップ演出確認"))
                    .font(.title3.weight(.semibold))
                Text(String(localized: "roadmap_transition.demo_subtitle", defaultValue: "LANDING / SCAN / DEPARTURE / FLYBY"))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.68))
            }
            Spacer()
            Button(String(localized: "common.close", defaultValue: "閉じる")) {
                router.show(.roadmap)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.white.opacity(0.12), in: Capsule())
        }
    }

    private var scenarioPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(RoadmapDemoScenario.allCases) { item in
                    Button {
                        scenario = item
                    } label: {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(item == scenario ? previewAccent : .white.opacity(0.08), in: Capsule())
                            .foregroundStyle(item == scenario ? .black : .white)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var checkpointHint: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "roadmap_transition.demo_steps", defaultValue: "確認手順"))
                .font(.headline)
            Text(String(localized: "roadmap_transition.demo_steps.detail", defaultValue: "着陸後にスキャン画面が出ます。認証すると離陸レバーへ移ります。"))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 18))
    }

    private var previewAccent: Color {
        checkpointDestination?.accent ?? {
            switch scenario {
            case .jupiterFlyby: Destination.jupiter.accent
            case .saturnFlyby: Destination.saturn.accent
            case .uranusFlyby: Destination.uranus.accent
            case .neptuneFlyby: Destination.neptune.accent
            case .plutoLanding: Destination.pluto.accent
            case .venusFlyby: Destination.venus.accent
            case .mercuryArrival: Destination.mercury.accent
            default: AppTheme.blue
            }
        }()
    }

    private func checkpointProgress(for destination: Destination) -> RoadmapProgress {
        let legIndex = RoadmapRoute.legs.firstIndex { $0.destination == destination } ?? 0
        let completedSeconds = RoadmapRoute.legs.prefix(legIndex + 1).reduce(0) { $0 + $1.requiredSeconds }
        return RoadmapProgress(totalSeconds: completedSeconds)
    }

    private var demoTaskKey: String {
        "\(scenario.rawValue)-\(checkpointDepartureStarted)-\(checkpointDepartureAnimating)"
    }

    @MainActor
    private func runDemoFlow() async {
        guard let checkpointDestination, !checkpointDepartureStarted else { return }
        showCheckpointScan = false
        try? await Task.sleep(for: .seconds(RoadmapTransition.arrival(checkpointDestination).duration))
        guard !Task.isCancelled, !checkpointDepartureStarted else { return }
        showCheckpointScan = true
    }

    private func resetScenario(_ scenario: RoadmapDemoScenario) {
        departureEffectsTask?.cancel()
        AudioService.shared.stop()
        startedAt = .now
        throttlePosition = 0
        checkpointAuthorized = false
        checkpointDepartureStarted = RoadmapDemoScenario.startsAtDepartureStage && checkpointDestination != nil
        checkpointDepartureAnimating = false
        showCheckpointScan = scenario == .roadmapScan
    }

    private func announceScenarioStart(_ scenario: RoadmapDemoScenario) {
        switch scenario {
        case .earthLaunch:
            break
        case .moonLanding:
            announceLanding(.moon)
        case .moonCheckpoint:
            announceLanding(.moon)
        case .marsLanding:
            announceLanding(.mars)
        case .marsCheckpoint:
            announceLanding(.mars)
        case .jupiterFlyby:
            announceFlyby(.jupiter)
        case .saturnFlyby:
            announceFlyby(.saturn)
        case .uranusFlyby:
            announceFlyby(.uranus)
        case .neptuneFlyby:
            announceFlyby(.neptune)
        case .plutoLanding:
            announceLanding(.pluto)
        case .plutoCheckpoint:
            announceLanding(.pluto)
        case .venusFlyby:
            announceFlyby(.venus)
        case .mercuryArrival:
            announceLanding(.mercury)
        case .roadmapScan:
            break
        }
    }

    private func announceLanding(_ destination: Destination) {
        if destination.isSurfaceDestination {
            let clipName: String? = switch destination {
            case .moon: "cabin_lunar_descent"
            case .mars: "cabin_mars_descent"
            case .pluto: "roadmap_pluto_descent"
            default: nil
            }
            AnnouncementService.shared.speakReplacingQueue(
                "まもなく\(destination.name)へ着陸します。降下姿勢を維持します。",
                clipName: clipName,
                chime: false,
                enabled: true
            )
        } else {
            AnnouncementService.shared.speakReplacingQueue(
                "まもなく\(destination.name)周回軌道へ投入します。減速姿勢を維持します。",
                clipName: "cabin_orbit_approach",
                chime: false,
                enabled: true
            )
        }
    }

    private func announceFlyby(_ destination: Destination) {
        let clipName: String? = switch destination {
        case .jupiter: "roadmap_jupiter_flyby"
        case .saturn: "roadmap_saturn_flyby"
        case .uranus: "roadmap_uranus_flyby"
        case .neptune: "roadmap_neptune_flyby"
        default: nil
        }
        AnnouncementService.shared.speakReplacingQueue(
            "\(destination.name)へ最接近します。外層に沿って通過します。",
            clipName: clipName,
            chime: false,
            enabled: true
        )
    }

    private func announceCheckpointDeparture() {
        AnnouncementService.shared.speak(
            "離床します。次の目的地へ向けて上昇します。",
            clipName: "cabin_liftoff",
            chime: false,
            enabled: true
        )
    }
}
#endif

private struct RoadmapFlybyScene: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let destination: Destination
    let next: Destination
    let progress: Double
    let displayMode: FocusDisplayMode

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let normalized = MissionVisualGeometry.eased(progress)
            ZStack {
                SpaceBackground(accent: destination.accent)
                    .scaleEffect(1 + normalized * 0.06)
                    .offset(
                        x: reduceMotion ? 0 : -CGFloat(normalized) * 28,
                        y: 0
                    )

                CelestialBodyView(kind: .destination(destination))
                    .frame(width: planetSize(in: size), height: planetSize(in: size))
                    .position(planetPosition(in: size))
                    .opacity(planetOpacity)

                CelestialBodyView(kind: .destination(next))
                    .frame(width: nextPlanetSize(in: size), height: nextPlanetSize(in: size))
                    .position(nextPlanetPosition(in: size))
                    .opacity(nextPlanetOpacity)

                LinearGradient(
                    colors: [.clear, destination.accent.opacity(0.10), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.screen)

                if displayMode.resolved == .cockpit {
                    Image("CockpitIntegratedLaunch")
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
        }
    }

    private func planetSize(in size: CGSize) -> CGFloat {
        let p = MissionVisualGeometry.eased(progress)
        let approach = min(p / 0.48, 1)
        let pass = min(max((p - 0.34) / 0.60, 0), 1)
        return min(size.width, size.height) * CGFloat(0.20 + approach * 0.96 + pass * 1.42)
    }

    private func planetPosition(in size: CGSize) -> CGPoint {
        let p = MissionVisualGeometry.eased(progress)
        let x: Double
        let y: Double

        if p < 0.32 {
            let local = p / 0.32
            x = 0.5
            y = 0.28 + local * 0.15
        } else if p < 0.94 {
            let local = (p - 0.32) / 0.62
            x = 0.5 - local * 1.16
            y = 0.43 + local * 0.08
        } else {
            let local = (p - 0.94) / 0.06
            x = -0.66 - local * 0.62
            y = 0.51 + local * 0.43
        }
        return CGPoint(x: size.width * x, y: size.height * y)
    }

    private var planetOpacity: Double {
        1
    }

    private func nextPlanetSize(in size: CGSize) -> CGFloat {
        let p = MissionVisualGeometry.eased(progress)
        let reveal = min(max((p - 0.996) / 0.004, 0), 1)
        return min(size.width, size.height) * CGFloat(0.055 + reveal * 0.095)
    }

    private func nextPlanetPosition(in size: CGSize) -> CGPoint {
        let p = MissionVisualGeometry.eased(progress)
        let reveal = min(max((p - 0.996) / 0.004, 0), 1)
        return CGPoint(
            x: size.width * 0.5,
            y: size.height * CGFloat(0.22 + reveal * 0.025)
        )
    }

    private var nextPlanetOpacity: Double {
        let p = MissionVisualGeometry.eased(progress)
        return min(max((p - 0.997) / 0.003, 0), 1)
    }

}

private struct RoadmapDepartureScene: View {
    let origin: Destination
    let next: Destination
    let phase: LaunchVisualPhase
    let phaseProgress: Double
    let displayMode: FocusDisplayMode
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                departureExterior(size: proxy.size)

                if displayMode.resolved == .cockpit {
                    Image("CockpitIntegratedLaunch")
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
            .offset(x: departureShake.width, y: departureShake.height)
        }
        .background(Color.black)
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func departureExterior(size: CGSize) -> some View {
        switch phase {
        case .standby, .ignition:
            ZStack {
                departureSurface(size: size)
                if phase == .ignition {
                    RadialGradient(
                        colors: [.white.opacity(0.66), origin.accent.opacity(0.42), .clear],
                        center: .bottom,
                        startRadius: 0,
                        endRadius: size.width * 0.72
                    )
                    .blendMode(.screen)
                }
            }
        case .ascent:
            let climb = MissionVisualGeometry.eased(phaseProgress)
            let skyDarkening = MissionVisualGeometry.eased(min(max((phaseProgress - 0.12) / 0.88, 0), 1))
            ZStack {
                LinearGradient(
                    colors: [
                        originSkyColor(top: true, factor: 1 - skyDarkening),
                        originSkyColor(top: false, factor: 1 - skyDarkening),
                        Color(red: 0.02 * (1 - skyDarkening), green: 0.05 * (1 - skyDarkening), blue: 0.10 * (1 - skyDarkening))
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                departureSurface(size: size)
                    .scaleEffect(1.02 + climb * 0.10)
                    .offset(y: climb * size.height * 0.64)
                    .opacity(max(0, 1 - MissionVisualGeometry.eased(min(phaseProgress / 0.68, 1))))

                localAscentCloudDeck(progress: phaseProgress)

                if phaseProgress > 0.68 {
                    localSparseStars(opacity: (phaseProgress - 0.68) / 0.32, fillsBackground: false)
                }

                if phaseProgress > 0.46 {
                    let insertion = MissionVisualGeometry.eased((phaseProgress - 0.46) / 0.54)
                    CelestialBodyView(kind: .destination(origin))
                        .frame(width: size.width * CGFloat(3.4 - insertion * 2.53))
                        .position(
                            x: size.width * 0.5,
                            y: size.height * CGFloat(0.84 - insertion * 0.09)
                        )
                        .opacity(min(insertion * 1.35, 1))

                    LinearGradient(
                        colors: [.clear, origin.accent.opacity(0.05 * insertion), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
        case .orbit:
            ZStack {
                localSparseStars(opacity: 1)
                CelestialBodyView(kind: .destination(origin))
                    .frame(width: size.width * 0.87)
                    .position(x: size.width * 0.5, y: size.height * 0.75)

                CelestialBodyView(kind: .destination(next))
                    .frame(width: MissionVisualGeometry.destinationWidth(next, progress: 0))
                    .position(x: size.width * 0.5, y: size.height * MissionVisualGeometry.destinationY(next, progress: 0))
                    .opacity(MissionVisualGeometry.eased(min(max((phaseProgress - 0.28) / 0.72, 0), 1)))
            }
        }
    }

    private func departureSurface(size: CGSize) -> some View {
        Group {
            switch origin {
            case .moon:
                landedSurfaceFrame(name: "MoonSurfaceNASA", size: size)
            case .mars:
                landedSurfaceFrame(name: "MarsSurfaceNASA", size: size)
            case .pluto:
                landedSurfaceFrame(name: "PlutoSurfaceNASA", size: size)
            default:
                Image("LaunchPadExterior")
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private func landedSurfaceFrame(name: String, size: CGSize) -> some View {
        Image(name)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .scaleEffect(1.12, anchor: .bottom)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.14),
                        .init(color: .white, location: 0.42),
                        .init(color: .white, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    private var departureShake: CGSize {
        guard phase == .ignition || phase == .ascent else { return .zero }
        let baseIntensity = phase == .ignition ? 9.5 : max(2.4, 7.2 - phaseProgress * 4.8)
        let intensity = reduceMotion ? baseIntensity * 0.24 : baseIntensity
        return CGSize(
            width: sin(phaseProgress * 196) * intensity,
            height: cos(phaseProgress * 241) * intensity
        )
    }

    private func originSkyColor(top: Bool, factor: Double) -> Color {
        switch origin {
        case .moon:
            return top
                ? Color(red: 0.01 + 0.03 * factor, green: 0.01 + 0.03 * factor, blue: 0.03 + 0.08 * factor)
                : Color(red: 0.02 * factor, green: 0.03 * factor, blue: 0.07 * factor)
        case .mars:
            return top
                ? Color(red: 0.16 * factor + 0.02, green: 0.08 * factor + 0.01, blue: 0.05 * factor + 0.02)
                : Color(red: 0.28 * factor + 0.02, green: 0.13 * factor + 0.01, blue: 0.08 * factor + 0.02)
        case .pluto:
            return top
                ? Color(red: 0.04 * factor + 0.01, green: 0.05 * factor + 0.01, blue: 0.08 * factor + 0.02)
                : Color(red: 0.08 * factor + 0.01, green: 0.09 * factor + 0.01, blue: 0.12 * factor + 0.02)
        default:
            return top
                ? Color(red: 0.035 * factor, green: 0.10 * factor, blue: 0.22 * factor)
                : Color(red: 0.0863 * factor, green: 0.2431 * factor, blue: 0.4235 * factor)
        }
    }

    private func localSparseStars(opacity: Double, fillsBackground: Bool = true) -> some View {
        Canvas(opaque: fillsBackground, colorMode: .linear, rendersAsynchronously: true) { context, size in
            if fillsBackground {
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            }
            for index in 0..<18 {
                let x = CGFloat((index * 431 + 59) % 997) / 997 * size.width
                let y = CGFloat((index * 677 + 31) % 991) / 991 * size.height * 0.74
                let radius: CGFloat = index % 6 == 0 ? 0.8 : 0.4
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius)),
                    with: .color(.white.opacity(opacity * (index % 5 == 0 ? 0.46 : 0.23)))
                )
            }
        }
    }

    private func localAscentCloudDeck(progress: Double) -> some View {
        Canvas(rendersAsynchronously: true) { context, size in
            guard progress > 0.12 && progress < 0.70 else { return }
            for index in 0..<8 {
                let local = (progress * 3.4 + Double(index) * 0.14).truncatingRemainder(dividingBy: 1)
                let width = size.width * CGFloat(1.2 + local * 0.55)
                let rect = CGRect(
                    x: (size.width - width) / 2,
                    y: size.height * CGFloat(local),
                    width: width,
                    height: 44 + CGFloat(local * 34)
                )
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(.white.opacity(0.025 + (1 - local) * 0.035))
                )
            }
        }
        .blur(radius: 12)
    }
}

struct RoadmapDepartureThrottleControl: View {
    @Binding var position: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                VStack(spacing: 7) {
                    Text("ENGINE CONTROL")
                        .font(.caption.weight(.semibold)).tracking(3).foregroundStyle(.cyan.opacity(0.9))
                    Text(LocalizedRuntime.text(ja: "レバーを下げて離陸", en: "Lower Lever to Launch"))
                        .font(.title3.weight(.bold))
                    Text(LocalizedRuntime.text(ja: "下までゆっくりドラッグしてください", en: "Drag it slowly all the way down"))
                        .font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.86))
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 13)
                .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.2)))
                .position(x: proxy.size.width * 0.5, y: proxy.size.height * 0.625)

                movableThrottle(size: proxy.size)

                Color.clear
                    .frame(width: 170, height: 230)
                    .contentShape(Rectangle())
                    .position(x: proxy.size.width * 0.5, y: proxy.size.height * 0.735)
                    .gesture(
                        DragGesture(minimumDistance: 2)
                            .onChanged { value in
                                position = min(max(value.translation.height / 118, 0), 1)
                            }
                            .onEnded { _ in
                                if position >= 0.88 {
                                    withAnimation(.easeOut(duration: 0.14)) { position = 1 }
                                } else {
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) { position = 0 }
                                }
                            }
                    )
                    .accessibilityLabel(LocalizedRuntime.text(ja: "離陸レバー", en: "Launch Lever"))
                    .accessibilityHint(LocalizedRuntime.text(ja: "下までドラッグすると離陸します", en: "Drag down to launch"))
            }
        }
        .ignoresSafeArea()
    }

    private func movableThrottle(size: CGSize) -> some View {
        let leverWidth = min(size.width * 0.087, 36)
        let leverHeight = leverWidth * 1.853
        let handleHeight = leverWidth * 0.383
        let pivotX = size.width * 0.5 - 2.5
        let pivotY = size.height * 0.807 - 3
        let angle = position * 82
        let projectedReach = leverHeight * 0.88 * cos(angle * .pi / 180)
        return ZStack {
            Image("CockpitThrottleStem")
                .resizable().scaledToFit()
                .frame(width: leverWidth, height: leverHeight)
                .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.72)
                .position(x: pivotX, y: pivotY - leverHeight / 2)
            Image("CockpitThrottleHandle")
                .resizable().scaledToFit()
                .frame(width: leverWidth, height: handleHeight)
                .scaleEffect(1 + position * 0.30)
                .position(x: pivotX, y: pivotY - projectedReach)
                .shadow(color: .black.opacity(0.72), radius: 4 + position * 3, y: 2 + position * 3)
        }
        .allowsHitTesting(false)
    }
}
