import Foundation
import Observation

struct SessionTelemetry: Sendable, Equatable {
    var updatedAt: Date
    var remainingDistanceKilometers: Double
    var phase: MissionPhase
}

@MainActor @Observable
final class FocusSessionManager {
    private(set) var session: FocusSession?
    private(set) var now = Date()
    private(set) var remainingSeconds: TimeInterval = 0
    private(set) var elapsedSeconds: TimeInterval = 0
    private(set) var progress: Double = 0
    private(set) var phase: MissionPhase = .launch
    private(set) var telemetry = SessionTelemetry(updatedAt: .distantPast, remainingDistanceKilometers: 0, phase: .launch)
    private(set) var completionRevision = 0

    private let persistence: SessionPersisting
    private let liveActivity: LiveActivityService
    private var tickerTask: Task<Void, Never>?
    private var applicationIsActive = true
    private var lastTelemetryUpdate = Date.distantPast
    private var lastLiveActivityUpdate = Date.distantPast
    private var lastLiveActivityPhase: MissionPhase?

    init(
        persistence: SessionPersisting? = nil,
        liveActivity: LiveActivityService? = nil
    ) {
        self.persistence = persistence ?? SessionPersistenceStore.shared
        self.liveActivity = liveActivity ?? LiveActivityService.shared
    }

    var status: FocusSessionStatus { session?.status ?? .idle }
    var sessionID: UUID? { session?.id }
    var missionID: UUID? { session?.missionID }
    var destination: Destination? { session?.destination }
    var displayMode: FocusDisplayMode { session?.displayMode ?? .cockpit }
    var isRunning: Bool { [.running, .approaching, .landing, .breakRunning].contains(status) }
    var isPaused: Bool { status.isPaused }

    func startSession(
        missionID: UUID,
        duration: TimeInterval,
        destination: Destination,
        displayMode: FocusDisplayMode = .cockpit,
        pomodoro: PomodoroConfiguration? = nil,
        currentCycle: Int = 1,
        now startDate: Date = .now
    ) {
        guard duration > 0 else { resetInvalidSession(); return }
        let newSession = FocusSession(
            missionID: missionID,
            startedAt: startDate,
            scheduledEndAt: startDate.addingTimeInterval(duration),
            configuredDuration: duration,
            destination: destination,
            status: .running,
            displayMode: displayMode,
            isPomodoro: pomodoro != nil,
            breakDuration: pomodoro?.shortBreakDuration ?? 0,
            pomodoroConfiguration: pomodoro,
            currentCycle: currentCycle
        )
        session = newSession
        refresh(at: startDate, forceTelemetry: true, forceLiveActivity: true, persist: true)
        startTickerIfNeeded()
    }

    func pauseSession(at date: Date = .now) {
        guard var session, [.running, .approaching, .landing].contains(session.status) else { return }
        refresh(at: date)
        session.pauseStartedAt = date
        session.pauseCount += 1
        session.status = .paused
        self.session = session
        refresh(at: date, forceTelemetry: true, forceLiveActivity: true, persist: true)
    }

    func resumeSession(at date: Date = .now) {
        guard var session, session.status == .paused, let pauseStartedAt = session.pauseStartedAt else { return }
        let paused = max(date.timeIntervalSince(pauseStartedAt), 0)
        session.accumulatedPausedDuration += paused
        session.scheduledEndAt = session.scheduledEndAt.addingTimeInterval(paused)
        session.pauseStartedAt = nil
        session.status = .running
        self.session = session
        refresh(at: date, forceTelemetry: true, forceLiveActivity: true, persist: true)
        startTickerIfNeeded()
    }

    func cancelSession(at date: Date = .now) {
        guard var session else { return }
        refresh(at: date)
        session.status = .cancelled
        session.completedAt = date
        self.session = session
        refresh(at: date, forceTelemetry: true, forceLiveActivity: true, persist: true)
        tickerTask?.cancel()
        if let current = self.session { Task { await liveActivity.end(session: current, phase: phase) } }
    }

    func completeSession(at date: Date = .now) {
        guard var session, session.status != .completed else { return }
        session.status = .completed
        session.completedAt = date
        session.pauseStartedAt = nil
        session.lastKnownElapsed = session.configuredDuration
        session.lastKnownRemaining = 0
        session.lastKnownProgress = 1
        self.session = session
        now = date
        remainingSeconds = 0
        elapsedSeconds = session.configuredDuration
        progress = 1
        phase = .landed
        updateTelemetry(at: date)
        persistence.saveSession(session)
        completionRevision += 1
        tickerTask?.cancel()
        Task { await liveActivity.end(session: session, phase: .landed) }
    }

    func restoreSession(at date: Date = .now) {
        guard let restored = persistence.loadSession(), restored.isValid else {
            resetInvalidSession()
            return
        }
        session = restored
        refresh(at: date, forceTelemetry: true, persist: true)
        if restored.status.isActive, remainingSeconds <= 0, !restored.status.isPaused {
            completeSession(at: date)
        } else {
            startTickerIfNeeded()
        }
    }

    func migrateLegacyMission(
        missionID: UUID,
        startedAt: Date?,
        scheduledEndAt: Date?,
        pausedRemainingSeconds: TimeInterval?,
        duration: TimeInterval,
        destination: Destination,
        isPaused: Bool,
        now date: Date = .now
    ) {
        guard session == nil, duration > 0 else { return }
        let start = startedAt ?? date
        let end: Date
        let pauseStart: Date?
        let status: FocusSessionStatus
        if isPaused {
            end = date.addingTimeInterval(max(pausedRemainingSeconds ?? duration, 0))
            pauseStart = date
            status = .paused
        } else {
            end = scheduledEndAt ?? start.addingTimeInterval(duration)
            pauseStart = nil
            status = .running
        }
        session = FocusSession(
            missionID: missionID,
            startedAt: start,
            scheduledEndAt: end,
            pauseStartedAt: pauseStart,
            configuredDuration: duration,
            destination: destination,
            status: status
        )
        refresh(at: date, forceTelemetry: true, persist: true)
        if remainingSeconds <= 0, !isPaused { completeSession(at: date) }
        else { startTickerIfNeeded() }
    }

    func startBreak(duration: TimeInterval? = nil, at date: Date = .now) {
        guard let previous = session else { return }
        let breakLength = duration ?? previous.pomodoroConfiguration?.breakDuration(after: previous.currentCycle) ?? previous.breakDuration
        guard breakLength > 0 else { return }
        session = FocusSession(
            missionID: previous.missionID,
            startedAt: date,
            scheduledEndAt: date.addingTimeInterval(breakLength),
            configuredDuration: breakLength,
            destination: previous.destination,
            status: .breakRunning,
            displayMode: .minimal,
            kind: .breakTime,
            isPomodoro: previous.isPomodoro,
            breakDuration: breakLength,
            pomodoroConfiguration: previous.pomodoroConfiguration,
            currentCycle: previous.currentCycle
        )
        refresh(at: date, forceTelemetry: true, persist: true)
        startTickerIfNeeded()
    }

    func pauseBreak(at date: Date = .now) {
        guard var session, session.status == .breakRunning else { return }
        session.pauseStartedAt = date
        session.pauseCount += 1
        session.status = .breakPaused
        self.session = session
        refresh(at: date, persist: true)
    }

    func resumeBreak(at date: Date = .now) {
        guard var session, session.status == .breakPaused, let pauseStartedAt = session.pauseStartedAt else { return }
        let paused = max(date.timeIntervalSince(pauseStartedAt), 0)
        session.accumulatedPausedDuration += paused
        session.scheduledEndAt = session.scheduledEndAt.addingTimeInterval(paused)
        session.pauseStartedAt = nil
        session.status = .breakRunning
        self.session = session
        refresh(at: date, persist: true)
        startTickerIfNeeded()
    }

    func completeBreak(at date: Date = .now) {
        completeSession(at: date)
    }

    func setApplicationActive(_ isActive: Bool, at date: Date = .now) {
        applicationIsActive = isActive
        if isActive {
            refresh(at: date, forceTelemetry: true, persist: true)
            if remainingSeconds <= 0, status.isActive, !status.isPaused { completeSession(at: date) }
            else { startTickerIfNeeded() }
        } else {
            refresh(at: date, persist: true)
            tickerTask?.cancel()
            tickerTask = nil
        }
    }

    func clearFinishedSession() {
        guard status == .completed || status == .cancelled || status == .idle else { return }
        session = nil
        remainingSeconds = 0
        elapsedSeconds = 0
        progress = 0
        phase = .launch
        persistence.clearSession()
    }

    func updateDisplayMode(_ displayMode: FocusDisplayMode) {
        guard var session, session.status.isActive else { return }
        session.displayMode = displayMode.resolved
        self.session = session
        persistence.saveSession(session)
    }

    private func startTickerIfNeeded() {
        guard applicationIsActive, status.isActive, !status.isPaused else { return }
        tickerTask?.cancel()
        tickerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                self.refresh(at: .now)
                if self.remainingSeconds <= 0 {
                    if self.status == .breakRunning { self.completeBreak() }
                    else { self.completeSession() }
                    return
                }
            }
        }
    }

    private func refresh(
        at date: Date,
        forceTelemetry: Bool = false,
        forceLiveActivity: Bool = false,
        persist: Bool = false
    ) {
        guard var session else { return }
        now = date
        remainingSeconds = session.remainingSeconds(at: date)
        elapsedSeconds = session.elapsedSeconds(at: date)
        progress = session.progress(at: date)
        phase = MissionPhase.resolve(progress: progress, destination: session.destination, completed: session.status == .completed)

        if !session.status.isPaused, !session.status.isBreak, session.status != .completed, session.status != .cancelled {
            if remainingSeconds <= 4 { session.status = .landing }
            else if remainingSeconds <= MissionVisualGeometry.arrivalSequenceDuration { session.status = .approaching }
            else { session.status = .running }
        }
        session.lastKnownElapsed = elapsedSeconds
        session.lastKnownRemaining = remainingSeconds
        session.lastKnownProgress = progress
        self.session = session

        if forceTelemetry || date.timeIntervalSince(lastTelemetryUpdate) >= 5 { updateTelemetry(at: date) }
        if persist { persistence.saveSession(session) }

        if session.status.isActive,
           !session.status.isBreak,
           (forceLiveActivity || date.timeIntervalSince(lastLiveActivityUpdate) >= 15 || lastLiveActivityPhase != phase) {
            lastLiveActivityUpdate = date
            lastLiveActivityPhase = phase
            Task { await liveActivity.update(session: session, phase: phase) }
        }
    }

    private func updateTelemetry(at date: Date) {
        guard let session else { return }
        telemetry = SessionTelemetry(
            updatedAt: date,
            remainingDistanceKilometers: remainingDistance(for: session, progress: progress),
            phase: phase
        )
        lastTelemetryUpdate = date
    }

    private func remainingDistance(for session: FocusSession, progress: Double) -> Double {
        let approachFraction = min(MissionVisualGeometry.arrivalSequenceDuration / session.configuredDuration, 1)
        let approachStart = 1 - approachFraction
        let finalDistance = session.destination.finalApproachKilometers
        if progress < approachStart, approachStart > 0 {
            let cruiseProgress = progress / approachStart
            return finalDistance + (session.destination.distanceKilometers - finalDistance) * (1 - cruiseProgress)
        }
        guard approachFraction > 0 else { return 0 }
        let approachProgress = min(max((progress - approachStart) / approachFraction, 0), 1)
        return finalDistance * (1 - approachProgress)
    }

    private func resetInvalidSession() {
        tickerTask?.cancel()
        tickerTask = nil
        session = nil
        now = .now
        remainingSeconds = 0
        elapsedSeconds = 0
        progress = 0
        phase = .launch
        telemetry = SessionTelemetry(updatedAt: .distantPast, remainingDistanceKilometers: 0, phase: .launch)
        persistence.clearSession()
    }
}

extension FocusSessionManager {
    static func preview(
        progress: Double = 0.42,
        destination: Destination = .mars,
        status: FocusSessionStatus = .running,
        displayMode: FocusDisplayMode = .cockpit
    ) -> FocusSessionManager {
        let store = InMemorySessionPersistenceStore()
        let manager = FocusSessionManager(persistence: store)
        let duration: TimeInterval = 45 * 60
        let now = Date()
        let elapsed = duration * progress
        store.session = FocusSession(
            startedAt: now.addingTimeInterval(-elapsed),
            scheduledEndAt: now.addingTimeInterval(duration - elapsed),
            configuredDuration: duration,
            destination: destination,
            status: status,
            displayMode: displayMode
        )
        manager.restoreSession(at: now)
        return manager
    }
}
