import SwiftData
import SwiftUI
import UIKit

@MainActor @Observable final class FlightViewModel {
    let mission: Mission
    let sessionManager: FocusSessionManager
    private let context: ModelContext
    var showInterruptionDialog = false
    var didFinish = false
    private var announcedMidpoint = false
    private var announcedArrival = false
    private var announcementsEnabled = true

    init(mission: Mission, context: ModelContext, sessionManager: FocusSessionManager) {
        self.mission = mission
        self.context = context
        self.sessionManager = sessionManager
    }

    var remainingSeconds: TimeInterval { sessionManager.remainingSeconds }
    var elapsedSeconds: TimeInterval { sessionManager.elapsedSeconds }
    var progress: Double { sessionManager.progress }
    var remainingDistance: Double { sessionManager.telemetry.remainingDistanceKilometers }
    var phase: MissionPhase { sessionManager.phase }
    var transitMessage: String {
        let messages = mission.destination.transitMessages
        return messages[min(Int(progress * Double(messages.count)), messages.count - 1)]
    }
    var shouldShowTransitMessage: Bool {
        let segment = (progress * 4).truncatingRemainder(dividingBy: 1)
        return progress < 0.018 || segment < 0.045
    }

    func begin(settings: AppSettings?) {
        announcementsEnabled = settings?.voiceAnnouncementsEnabled ?? true
        if sessionManager.missionID != mission.id || sessionManager.session == nil {
            sessionManager.startSession(
                missionID: mission.id,
                duration: mission.totalSeconds,
                destination: mission.destination,
                displayMode: settings?.flightDisplayMode ?? .cockpit,
                pomodoro: mission.pomodoroConfiguration
            )
        }
        synchronizeLegacyMission()
        UIApplication.shared.isIdleTimerDisabled = true
        AudioService.shared.startIfEnabled(settings?.ambientSoundEnabled ?? true)
        AnnouncementService.shared.speak(
            LocalizedRuntime.text(
                ja: "ご搭乗ありがとうございます。当船はただいま、\(mission.destination.name)に向けて、自動航行へ移行いたしました。到着まで、どうぞ静かにお過ごしください。",
                en: "Thank you for boarding. This craft is now transitioning to autopilot for \(mission.destination.name). Please enjoy a quiet focus period until arrival."
            ),
            clipName: "cabin_cruise",
            enabled: announcementsEnabled
        )
        if settings?.completionNotificationEnabled ?? true,
           !sessionManager.isPaused,
           let endDate = sessionManager.session?.scheduledEndAt {
            let missionID = mission.id
            let destinationName = mission.destination.name
            Task { await NotificationService.shared.scheduleCompletion(missionID: missionID, destinationName: destinationName, endDate: endDate) }
        }
        announceFlightStatusIfNeeded()
    }

    func handleManagerUpdate() {
        synchronizeLegacyMission()
        announceFlightStatusIfNeeded()
    }

    private func synchronizeLegacyMission() {
        guard let session = sessionManager.session, session.missionID == mission.id else { return }
        mission.startDate = session.startedAt
        mission.expectedEndDate = session.scheduledEndAt
        mission.pausedRemainingSeconds = session.status.isPaused ? session.lastKnownRemaining : nil
        switch session.status {
        case .paused: mission.status = .paused
        case .completed: mission.status = .completed
        case .cancelled: mission.status = .interrupted
        default: mission.status = .flying
        }
        try? context.save()
    }

    private func announceFlightStatusIfNeeded() {
        if progress >= 0.5, !announcedMidpoint {
            announcedMidpoint = true
            if progress < 0.75 {
                AnnouncementService.shared.speak(
                    LocalizedRuntime.text(ja: "航程の半分を通過しました。航行は順調です。", en: "You have passed the halfway point. Flight conditions remain stable."),
                    clipName: "cabin_midpoint",
                    enabled: announcementsEnabled
                )
            }
        }
        if remainingSeconds <= 12, !announcedArrival {
            announcedArrival = true
            AnnouncementService.shared.speakReplacingQueue(
                approachAnnouncement,
                clipName: approachClipName,
                chime: false,
                enabled: announcementsEnabled
            )
        }
    }

    private var approachClipName: String {
        switch mission.destination {
        case .moon: "cabin_lunar_descent"
        case .mars, .pluto: "cabin_mars_descent"
        case .station: "cabin_docking_approach"
        case .mercury, .venus, .jupiter, .saturn, .uranus, .neptune: "cabin_orbit_approach"
        }
    }

    private var approachAnnouncement: String {
        switch mission.destination {
        case .moon: LocalizedRuntime.text(ja: "月面への最終降下を開始します。接地まで、そのままお待ちください。", en: "Beginning final descent to the Moon. Please remain seated until touchdown.")
        case .mars: LocalizedRuntime.text(ja: "火星地表への最終降下を開始します。降下速度は正常です。", en: "Beginning final descent to the Martian surface. Descent velocity is nominal.")
        case .pluto: LocalizedRuntime.text(ja: "冥王星地表への最終降下を開始します。降下速度は正常です。", en: "Beginning final descent to Pluto. Descent velocity is nominal.")
        case .station: LocalizedRuntime.text(ja: "宇宙ステーションとの最終ドッキングシーケンスを開始します。", en: "Beginning the final docking sequence with the space station.")
        case .mercury, .venus, .jupiter, .saturn, .uranus, .neptune: LocalizedRuntime.text(ja: "目的地周回軌道への投入を開始します。", en: "Beginning orbital insertion around the destination.")
        }
    }

    func togglePause() {
        if sessionManager.isPaused {
            sessionManager.resumeSession()
            synchronizeLegacyMission()
            if let endDate = sessionManager.session?.scheduledEndAt {
                let missionID = mission.id
                let destinationName = mission.destination.name
                Task { await NotificationService.shared.scheduleCompletion(missionID: missionID, destinationName: destinationName, endDate: endDate) }
            }
            AnnouncementService.shared.speak(LocalizedRuntime.text(ja: "自動航行を再開します。", en: "Resuming autopilot."), clipName: "cabin_resume", chime: false, enabled: announcementsEnabled)
        } else {
            sessionManager.pauseSession()
            synchronizeLegacyMission()
            NotificationService.shared.cancel(missionID: mission.id)
            AnnouncementService.shared.speak(LocalizedRuntime.text(ja: "航行を一時停止しました。準備ができましたら、再開してください。", en: "Flight has been paused. Resume when you are ready."), clipName: "cabin_pause", chime: false, enabled: announcementsEnabled)
        }
    }

    func interrupt() {
        guard !didFinish else { return }
        let actualSeconds = sessionManager.elapsedSeconds
        sessionManager.cancelSession()
        synchronizeLegacyMission()
        AnnouncementService.shared.stop()
        context.insert(MissionRecord(
            mission: mission,
            actualSeconds: actualSeconds,
            completed: false,
            pauseCount: sessionManager.session?.pauseCount ?? 0,
            displayMode: sessionManager.displayMode,
            session: sessionManager.session
        ))
        cleanup()
        AnnouncementService.shared.speak(LocalizedRuntime.text(ja: "航行を終了しました。現在までの記録を保存しました。", en: "Flight ended. Your progress so far has been saved."), clipName: "cabin_interrupted", chime: false, enabled: announcementsEnabled)
        try? context.save(); didFinish = true
    }

    func cleanup() {
        NotificationService.shared.cancel(missionID: mission.id); AudioService.shared.stop(); UIApplication.shared.isIdleTimerDisabled = false
    }
}
