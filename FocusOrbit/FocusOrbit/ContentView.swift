import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var missions: [Mission]
    @Query private var records: [MissionRecord]
    @Query private var roadmapRecords: [RoadmapFocusRecord]
    @Query private var profiles: [CrewProfile]
    @Query private var settings: [AppSettings]
    @State private var router = AppRouter()
    @State private var isShowingSplash = true
    @State private var shouldPrepareAppOpenAd = false
    @State private var advertisingConfigured = false
    let sessionManager: FocusSessionManager
    let roadmapSessionManager: RoadmapSessionManager
    let appOpenAdManager: AppOpenAdManager
    let interstitialAdManager: InterstitialAdManager

    private var profile: CrewProfile? { profiles.first }
    private var appSettings: AppSettings? { settings.first }
    private var selectedMission: Mission? { missions.first { $0.id == router.missionID } }
    private var showsGlobalTabs: Bool {
        if isShowingSplash { return false }
        switch router.screen {
        case .introduction, .roadmapPass, .launch, .flight, .arrival, .result, .breakSession, .roadmapFocus, .missionPass:
            return false
        default:
            return true
        }
    }

    var body: some View {
        ZStack {
            SpaceBackground(accent: selectedMission?.destination.accent ?? AppTheme.blue)
            Group {
                switch router.screen {
                case .introduction:
                    if let appSettings { IntroductionView(router: router, settings: appSettings) }
                case .home:
                    HomeView(
                        router: router,
                        interstitialAdManager: interstitialAdManager,
                        records: records,
                        roadmapRecords: roadmapRecords,
                        profile: profile,
                        settings: appSettings
                    )
                case .roadmap:
                    RoadmapView(router: router, records: roadmapRecords, sessionManager: roadmapSessionManager)
                case .roadmapPass:
                    RoadmapPassView(
                        router: router,
                        progress: RoadmapProgress(totalSeconds: RoadmapStorageService.totalSeconds(roadmapRecords) + roadmapSessionManager.elapsedSeconds),
                        crewName: profile?.crewName ?? "CREW",
                        settings: appSettings,
                        sessionManager: roadmapSessionManager
                    )
                case .roadmapLaunch:
                    LaunchCountdownView(destination: .moon, settings: appSettings) {
                        roadmapSessionManager.startSession()
                        roadmapSessionManager.acknowledgeInitialLaunch()
                        router.show(.roadmapFocus)
                    }
                case .roadmapFocus:
                    RoadmapFocusView(
                        router: router,
                        records: roadmapRecords,
                        crewName: profile?.crewName ?? "CREW",
                        settings: appSettings,
                        sessionManager: roadmapSessionManager
                    )
                case .setup: MissionSetupView(router: router, existingCount: records.count, settings: appSettings, records: records, initialDraft: router.missionDraft)
                case .missionPass:
                    if let selectedMission { MissionPassView(router: router, mission: selectedMission, crewName: profile?.crewName ?? "CREW", settings: appSettings) }
                case .launch:
                    if let selectedMission { LaunchCountdownView(router: router, mission: selectedMission, settings: appSettings) }
                case .flight:
                    if let selectedMission { FlightView(router: router, mission: selectedMission, settings: appSettings, sessionManager: sessionManager) }
                case .arrival:
                    if let selectedMission { ArrivalView(router: router, mission: selectedMission, settings: appSettings, sessionManager: sessionManager) }
                case .result:
                    if let selectedMission, let record = records.first(where: { $0.missionNumber == selectedMission.missionNumber }) {
                        MissionResultView(router: router, mission: selectedMission, record: record, crewName: profile?.crewName ?? "CREW", sessionManager: sessionManager, allRecords: records, settings: appSettings)
                    }
                case .breakSession:
                    if let selectedMission {
                        BreakView(router: router, sessionManager: sessionManager, mission: selectedMission, settings: appSettings, recordCount: records.count)
                    }
                case .logs:
                    MissionLogView(
                        router: router,
                        interstitialAdManager: interstitialAdManager,
                        records: records,
                        roadmapRecords: roadmapRecords,
                        settings: appSettings
                    )
                case let .missionDetail(id):
                    if let record = records.first(where: { $0.id == id }) { MissionDetailView(router: router, record: record, crewName: profile?.crewName ?? "CREW") }
                case .crew: CrewCardView(router: router, profile: profile, records: records, roadmapRecords: roadmapRecords)
                case .settings: SettingsView(router: router, profile: profile, settings: appSettings)
                }
            }
            .id(router.screen)
            .transition(.opacity)

            if isShowingSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(20)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsGlobalTabs {
                GlobalNavigationTabBar(router: router, interstitialAdManager: interstitialAdManager)
            }
        }
        .animation(.easeInOut(duration: 0.38), value: router.screen)
        .task {
            bootstrap()
            try? await Task.sleep(for: .seconds(2.6))
            withAnimation(.easeOut(duration: 0.28)) {
                isShowingSplash = false
            }
            await configureAdvertisingIfNeeded()
        }
        .task(id: advertisingBootstrapKey) {
            await configureAdvertisingIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            sessionManager.setApplicationActive(phase == .active)
            roadmapSessionManager.setApplicationActive(phase == .active)
            if phase == .active {
                restoreRouteFromSession()
            }
        }
    }

    private func bootstrap() {
        if profiles.isEmpty { context.insert(CrewProfile()) }
        let resolvedSettings: AppSettings
        if let existing = settings.first {
            resolvedSettings = existing
        } else {
            let created = AppSettings()
            context.insert(created)
            resolvedSettings = created
        }
        shouldPrepareAppOpenAd = resolvedSettings.hasCompletedIntroduction
        try? context.save()
        sessionManager.restoreSession()
        roadmapSessionManager.restoreSession()
#if DEBUG
        let demoScreen = ProcessInfo.processInfo.environment["FOCUSORBIT_DEMO"]
        let demoDestination = Destination(rawValue: ProcessInfo.processInfo.environment["FOCUSORBIT_DESTINATION"] ?? "") ?? .mars
        if demoScreen == "home" {
            sessionManager.clearFinishedSession()
            router.show(.home)
            return
        }
        if demoScreen == "roadmap" {
            sessionManager.clearFinishedSession()
            router.show(.roadmap)
            return
        }
        if demoScreen == "roadmapPass" {
            sessionManager.clearFinishedSession()
            router.show(.roadmapPass)
            return
        }
        if demoScreen == "roadmapLaunch" {
            sessionManager.clearFinishedSession()
            router.show(.roadmapLaunch)
            return
        }
        if demoScreen == "roadmapFocus" {
            sessionManager.clearFinishedSession()
            if !roadmapSessionManager.isActive { roadmapSessionManager.startSession() }
            router.show(.roadmapFocus)
            return
        }
        if demoScreen == "setup" {
            sessionManager.clearFinishedSession()
            router.show(.setup)
            return
        }
        if demoScreen == "settings" {
            sessionManager.clearFinishedSession()
            router.show(.settings)
            return
        }
        if demoScreen == "crew" {
            sessionManager.clearFinishedSession()
            router.show(.crew)
            return
        }
        if demoScreen == "logs" {
            sessionManager.clearFinishedSession()
            router.show(.logs)
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--demo-flight") || demoScreen == "flight" {
            let demo = Mission(missionNumber: "MS-0048", focusTitle: "経済学レポート", durationMinutes: 45, destination: demoDestination)
            demo.startDate = Date().addingTimeInterval(-12 * 60 - 42)
            demo.expectedEndDate = Date().addingTimeInterval(32 * 60 + 18)
            demo.status = .flying
            context.insert(demo); try? context.save()
            if let rawDuration = ProcessInfo.processInfo.environment["FOCUSORBIT_DEMO_FLIGHT_SECONDS"],
               let duration = TimeInterval(rawDuration), duration > 0 {
                sessionManager.startSession(
                    missionID: demo.id,
                    duration: duration,
                    destination: demoDestination,
                    displayMode: resolvedSettings.flightDisplayMode
                )
            }
            router.show(.flight, missionID: demo.id)
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--demo-pass") || demoScreen == "pass" {
            let demo = Mission(missionNumber: "MS-0048", focusTitle: "経済学レポート", durationMinutes: 45, destination: demoDestination)
            context.insert(demo); try? context.save()
            router.show(.missionPass, missionID: demo.id)
            return
        }
        if demoScreen == "launch" || demoScreen == "arrival" {
            let demo = Mission(missionNumber: "MS-0048", focusTitle: "経済学レポート", durationMinutes: 45, destination: demoDestination)
            demo.status = demoScreen == "launch" ? .launching : .completed
            context.insert(demo); try? context.save()
            if demoScreen == "arrival" {
                let demoDuration = ProcessInfo.processInfo.environment["FOCUSORBIT_DEMO_ARRIVAL_SECONDS"].flatMap(TimeInterval.init)
                    ?? MissionVisualGeometry.arrivalSequenceDuration
                sessionManager.startSession(missionID: demo.id, duration: demoDuration, destination: demoDestination)
            }
            router.show(demoScreen == "launch" ? .launch : .arrival, missionID: demo.id)
            return
        }
        if demoScreen == "result" {
            let demo = Mission(missionNumber: "DEMO-\(Int(Date().timeIntervalSince1970))", focusTitle: "経済学レポート", durationMinutes: 25, destination: demoDestination)
            demo.status = .completed
            context.insert(demo)
            context.insert(MissionRecord(mission: demo, actualSeconds: 25 * 60, completed: true, pauseCount: 1, displayMode: resolvedSettings.flightDisplayMode))
            sessionManager.startSession(missionID: demo.id, duration: 1, destination: demoDestination, displayMode: resolvedSettings.flightDisplayMode)
            sessionManager.completeSession()
            try? context.save()
            router.show(.result, missionID: demo.id)
            return
        }
#endif
        migrateLegacySessionIfNeeded()
        if roadmapSessionManager.isActive {
            router.screen = .roadmapFocus
            return
        }
        if let preflightStage = roadmapSessionManager.preflightStage {
            router.screen = preflightStage == .pass ? .roadmapPass : .roadmapLaunch
            return
        }
        if restoreRouteFromSession() { return }
        if !resolvedSettings.hasCompletedIntroduction {
            router.screen = .introduction
            return
        }
        if let active = missions.first(where: { [.flying, .paused, .launching].contains($0.status) }) {
            router.missionID = active.id
            router.screen = active.status == .launching ? .launch : .flight
        }
    }

    private var advertisingBootstrapKey: String {
        let introCompleted = appSettings?.hasCompletedIntroduction == true
        let requestedTracking = appSettings?.hasRequestedTrackingPermission == true
        let sceneIsActive = scenePhase == .active
        return "\(isShowingSplash)-\(introCompleted)-\(requestedTracking)-\(sceneIsActive)"
    }

    @MainActor
    private func configureAdvertisingIfNeeded() async {
        guard !advertisingConfigured,
              !isShowingSplash,
              scenePhase == .active,
              let settings = appSettings,
              settings.hasCompletedIntroduction else { return }

        let requestedTracking = await TrackingAuthorizationManager.shared.requestTrackingIfNeeded(settings: settings)
        try? context.save()

        TrackingAuthorizationManager.shared.startMobileAdsIfNeeded()
        interstitialAdManager.preloadIfNeeded()

        if shouldPrepareAppOpenAd, !requestedTracking {
            appOpenAdManager.prepareLaunchAd()
            appOpenAdManager.markPrimaryInterfaceReady()
        }

        advertisingConfigured = true
    }

    private func migrateLegacySessionIfNeeded() {
        guard sessionManager.session == nil,
              let active = missions.first(where: { [.flying, .paused].contains($0.status) }) else { return }
        sessionManager.migrateLegacyMission(
            missionID: active.id,
            startedAt: active.startDate,
            scheduledEndAt: active.expectedEndDate,
            pausedRemainingSeconds: active.pausedRemainingSeconds,
            duration: active.totalSeconds,
            destination: active.destination,
            isPaused: active.status == .paused
        )
    }

    @discardableResult
    private func restoreRouteFromSession() -> Bool {
        if roadmapSessionManager.isActive {
            router.screen = .roadmapFocus
            return true
        }
        guard let session = sessionManager.session,
              let missionID = session.missionID,
              let mission = missions.first(where: { $0.id == missionID }) else { return false }
        router.missionID = missionID
        if session.kind == .breakTime {
            router.screen = .breakSession
            return true
        }
        switch session.status {
        case .completed:
            mission.status = .completed
            if !records.contains(where: { $0.missionNumber == mission.missionNumber }) {
                context.insert(MissionRecord(mission: mission, actualSeconds: mission.totalSeconds, completed: true, pauseCount: session.pauseCount, displayMode: session.displayMode, session: session))
            }
            try? context.save()
            router.screen = .arrival
            return true
        case .cancelled:
            return false
        case .paused:
            mission.status = .paused
            mission.pausedRemainingSeconds = session.lastKnownRemaining
            router.screen = .flight
            return true
        case .approaching, .landing:
            mission.status = .flying
            router.screen = .flight
            return true
        case .running:
            mission.status = .flying
            router.screen = .flight
            return true
        case .preparing:
            router.screen = .launch
            return true
        case .breakRunning, .breakPaused, .idle:
            return false
        }
    }
}

private struct GlobalNavigationTabBar: View {
    let router: AppRouter
    let interstitialAdManager: InterstitialAdManager

    var body: some View {
        HStack(spacing: 10) {
            tabItem(.home, title: LocalizedRuntime.text(ja: "ホーム", en: "Home"), symbol: "house.fill")
            tabItem(.logs, title: LocalizedRuntime.text(ja: "航行ログ", en: "Logs"), symbol: "list.bullet.rectangle")
            tabItem(.crew, title: LocalizedRuntime.text(ja: "クルー", en: "Crew"), symbol: "person.text.rectangle")
            tabItem(.settings, title: LocalizedRuntime.text(ja: "設定", en: "Settings"), symbol: "slider.horizontal.3")
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.black.opacity(0.86))
        .overlay(alignment: .top) {
            Rectangle().fill(.white.opacity(0.06)).frame(height: 1)
        }
    }

    private func tabItem(_ screen: AppScreen, title: String, symbol: String) -> some View {
        let active = isActive(screen)
        return Button {
            guard !active else { return }
            interstitialAdManager.handleTrigger {
                router.show(screen)
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(active ? AppTheme.blue.opacity(0.16) : .white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(active ? AppTheme.blue.opacity(0.24) : .white.opacity(0.08)))
            .foregroundStyle(active ? AppTheme.blue : AppTheme.secondary)
        }
        .buttonStyle(.plain)
    }

    private func isActive(_ screen: AppScreen) -> Bool {
        switch (router.screen, screen) {
        case (.home, .home), (.logs, .logs), (.crew, .crew), (.settings, .settings):
            return true
        default:
            return false
        }
    }
}

#Preview {
    ContentView(
        sessionManager: .preview(),
        roadmapSessionManager: RoadmapSessionManager(defaults: UserDefaults(suiteName: "preview.roadmap")!),
        appOpenAdManager: AppOpenAdManager(),
        interstitialAdManager: InterstitialAdManager()
    )
        .modelContainer(for: [Mission.self, MissionRecord.self, RoadmapFocusRecord.self, CrewProfile.self, AppSettings.self], inMemory: true)
}
