import SwiftData
import SwiftUI
import UIKit

struct ArrivalView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    let router: AppRouter
    let mission: Mission
    let settings: AppSettings?
    let sessionManager: FocusSessionManager
    @State private var completed = false
    @State private var handledCompletion = false

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: reduceMotion ? 1 / 12 : 1 / 60, paused: scenePhase != .active)) { timeline in
                let progress = arrivalProgress(at: timeline.date)
                ZStack {
                    ArrivalVisualScene(
                        destination: mission.destination,
                        progress: progress,
                        startingFlightProgress: arrivalStartMissionProgress,
                        displayMode: sessionManager.displayMode,
                        reduceMotion: reduceMotion
                    )
                    VStack {
                    HStack {
                        arrivalBadge(progress)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(progress >= 1 ? completionSignal : "T-\(Formatters.countdown(max(contactDate.timeIntervalSince(timeline.date), 0)))")
                                .font(.caption2).tracking(1.4).monospacedDigit()
                            Text(altitudeLabel(progress)).font(.system(size: 8, design: .monospaced)).tracking(1).foregroundStyle(AppTheme.secondary)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, max(proxy.safeAreaInsets.top + 14, 28))
                    Spacer()
                    VStack(spacing: 7) {
                        Text(completed ? "MISSION COMPLETE" : arrivalStage(progress)).font(.system(size: completed ? 28 : 22, weight: .light, design: .rounded)).tracking(2)
                        Text(completed ? completionMessage : guidanceMessage(progress)).font(.caption).tracking(1.2).foregroundStyle(AppTheme.secondary)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(.black.opacity(0.46), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.08)))
                    .padding(.bottom, proxy.size.width > proxy.size.height ? max(proxy.safeAreaInsets.bottom + 28, 44) : 140)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .statusBarHidden(true)
        .task {
            if sessionManager.status == .completed {
                await handleCompletion()
            }
        }
        .onChange(of: sessionManager.completionRevision) { _, _ in
            Task { await handleCompletion() }
        }
    }

    private var contactDate: Date {
        sessionManager.session?.scheduledEndAt ?? mission.expectedEndDate ?? .now
    }

    private var arrivalStartMissionProgress: Double {
        let duration = sessionManager.session?.configuredDuration ?? mission.totalSeconds
        guard duration > 0 else { return 1 }
        return max(0, 1 - MissionVisualGeometry.arrivalSequenceDuration / duration)
    }

    private func arrivalProgress(at date: Date) -> Double {
        let duration = MissionVisualGeometry.arrivalSequenceDuration
        return min(max(1 - contactDate.timeIntervalSince(date) / duration, 0), 1)
    }

    private func synchronizeCompletedMission() {
        mission.status = .completed
        let missionNumber = mission.missionNumber
        let descriptor = FetchDescriptor<MissionRecord>(predicate: #Predicate { $0.missionNumber == missionNumber })
        if (try? context.fetchCount(descriptor)) == 0 {
            context.insert(MissionRecord(
                mission: mission,
                actualSeconds: sessionManager.elapsedSeconds,
                completed: true,
                pauseCount: sessionManager.session?.pauseCount ?? 0,
                displayMode: sessionManager.displayMode,
                session: sessionManager.session
            ))
        }
        NotificationService.shared.cancel(missionID: mission.id)
        AudioService.shared.stop()
        UIApplication.shared.isIdleTimerDisabled = false
        try? context.save()
    }

    @MainActor
    private func handleCompletion() async {
        guard !handledCompletion else { return }
        handledCompletion = true
        synchronizeCompletedMission()
        MissionHaptics.landing(enabled: settings?.hapticsEnabled ?? true, reduceMotion: reduceMotion)
        AudioService.shared.playLandingImpactIfEnabled(
            settings?.ambientSoundEnabled ?? true,
            dustySurface: mission.destination.isSurfaceDestination
        )
        let voiceEnabled = settings?.voiceAnnouncementsEnabled ?? true
        AnnouncementService.shared.speakReplacingQueue(
            completionAnnouncement,
            clipName: completionClipName,
            chime: false,
            enabled: voiceEnabled
        )
        try? await Task.sleep(for: .milliseconds(260))
        MissionHaptics.completed(enabled: settings?.hapticsEnabled ?? true)
        completed = true
        try? await Task.sleep(for: .seconds(2.8))
        router.show(.result)
    }

    private var arrivalMode: String {
        switch mission.destination {
        case .moon: LocalizedRuntime.text(ja: "月面最終進入", en: "LUNAR FINAL")
        case .mars: LocalizedRuntime.text(ja: "火星最終進入", en: "MARS FINAL")
        case .pluto: LocalizedRuntime.text(ja: "冥王星最終進入", en: "PLUTO FINAL")
        case .station: LocalizedRuntime.text(ja: "ステーション接近", en: "STATION APPROACH")
        default: LocalizedRuntime.text(ja: "周回軌道投入", en: "ORBIT INSERTION")
        }
    }
    private func arrivalStage(_ progress: Double) -> String {
        if progress < 0.35 { return "DECELERATION" }
        if progress < 0.72 { return mission.destination == .station ? "RENDEZVOUS" : "FINAL APPROACH" }
        if mission.destination.isSurfaceDestination { return progress < 0.995 ? "FINAL DESCENT" : "TOUCHDOWN" }
        if mission.destination == .station { return progress < 0.995 ? "FINAL DOCKING" : "CAPTURE" }
        return "ORBITAL INSERTION"
    }
    private func altitudeLabel(_ progress: Double) -> String {
        if mission.destination == .station {
            return "RANGE \(max(0, Int(ceil((1 - progress) * 120)))) M"
        }
        if mission.destination.isOrbitalDestination {
            return "ORBIT \(max(0, Int(ceil((1 - progress) * 12_000)))) KM"
        }
        guard mission.destination.isSurfaceDestination else { return "FINAL VECTOR" }
        let altitude = max(0, Int((1 - progress) * 18_000))
        return "ALT \(altitude) M"
    }
    private func guidanceMessage(_ progress: Double) -> String {
        if progress >= 0.995, mission.destination.isSurfaceDestination { return LocalizedRuntime.text(ja: "接地を確認しました", en: "Touchdown confirmed") }
        if progress >= 0.995, mission.destination == .station { return LocalizedRuntime.text(ja: "ドッキングポートを固定しました", en: "Docking port secured") }
        if progress > 0.72 {
            if mission.destination == .station { return LocalizedRuntime.text(ja: "相対速度を制御しています", en: "Controlling relative velocity") }
            if mission.destination.isOrbitalDestination { return LocalizedRuntime.text(ja: "減速し周回軌道へ投入しています", en: "Decelerating into orbital insertion") }
            return LocalizedRuntime.text(ja: "降下速度を制御しています", en: "Controlling descent velocity")
        }
        return LocalizedRuntime.text(ja: "目的地への最終進入を継続しています", en: "Continuing final approach to destination")
    }
    private var completionSignal: String {
        switch mission.destination { case .moon, .mars, .pluto: "TOUCHDOWN"; case .station: "DOCKED"; case .mercury, .venus, .jupiter, .saturn, .uranus, .neptune: "ORBIT" }
    }
    private var completionMessage: String {
        switch mission.destination {
        case .moon: LocalizedRuntime.text(ja: "月へ着陸しました", en: "Landed on the Moon")
        case .mars: LocalizedRuntime.text(ja: "火星へ着陸しました", en: "Landed on Mars")
        case .station: LocalizedRuntime.text(ja: "ドッキングが完了しました", en: "Docking complete")
        case .mercury: LocalizedRuntime.text(ja: "水星周回軌道へ投入しました", en: "Entered orbit around Mercury")
        case .venus: LocalizedRuntime.text(ja: "金星周回軌道へ投入しました", en: "Entered orbit around Venus")
        case .jupiter: LocalizedRuntime.text(ja: "木星へ到達しました", en: "Arrived at Jupiter")
        case .saturn: LocalizedRuntime.text(ja: "土星周回軌道へ投入しました", en: "Entered orbit around Saturn")
        case .uranus: LocalizedRuntime.text(ja: "天王星周回軌道へ投入しました", en: "Entered orbit around Uranus")
        case .neptune: LocalizedRuntime.text(ja: "海王星周回軌道へ投入しました", en: "Entered orbit around Neptune")
        case .pluto: LocalizedRuntime.text(ja: "冥王星へ着陸しました", en: "Landed on Pluto")
        }
    }
    private var completionAnnouncement: String {
        LocalizedRuntime.text(ja: "\(completionMessage)。長時間の航行、お疲れさまでした。", en: "\(completionMessage). Long-duration flight complete. Well done.")
    }
    private var completionClipName: String {
        switch mission.destination {
        case .moon: "cabin_lunar_complete"
        case .mars, .pluto: "cabin_mars_complete"
        case .station: "cabin_station_complete"
        case .mercury, .venus, .jupiter, .saturn, .uranus, .neptune: "cabin_orbit_complete"
        }
    }

    private func arrivalBadge(_ progress: Double) -> some View {
        HStack(spacing: 8) {
            Text(arrivalMode)
                .font(.caption2.weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(mission.destination.accent)
            if !completed {
                Text(arrivalStage(progress))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.black.opacity(0.38), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.08)))
    }
}
