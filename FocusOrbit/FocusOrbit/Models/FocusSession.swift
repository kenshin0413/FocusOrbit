import Foundation

enum FocusSessionStatus: String, Codable, CaseIterable, Sendable {
    case idle
    case preparing
    case running
    case paused
    case approaching
    case landing
    case completed
    case cancelled
    case breakRunning
    case breakPaused

    var isActive: Bool {
        switch self {
        case .preparing, .running, .paused, .approaching, .landing, .breakRunning, .breakPaused: true
        default: false
        }
    }

    var isPaused: Bool { self == .paused || self == .breakPaused }
    var isBreak: Bool { self == .breakRunning || self == .breakPaused }
}

enum FocusDisplayMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case cockpit
    case cinematic
    case simple
    case audioOnly
    // Kept for sessions saved before the four display modes were introduced.
    case minimal

    var id: String { rawValue }

    static var selectableCases: [FocusDisplayMode] { [.cockpit, .cinematic, .simple, .audioOnly] }

    var resolved: FocusDisplayMode { self == .minimal ? .simple : self }

    var japaneseTitle: String {
        switch resolved {
        case .cockpit: LocalizedRuntime.text(ja: "コックピット", en: "Cockpit")
        case .cinematic: LocalizedRuntime.text(ja: "シネマティック", en: "Cinematic")
        case .simple: LocalizedRuntime.text(ja: "シンプル", en: "Simple")
        case .audioOnly: LocalizedRuntime.text(ja: "画面消灯・音のみ", en: "Audio Only")
        case .minimal: LocalizedRuntime.text(ja: "シンプル", en: "Simple")
        }
    }

    var englishTitle: String {
        switch resolved {
        case .cockpit: "COCKPIT"
        case .cinematic: "CINEMATIC"
        case .simple: "SIMPLE"
        case .audioOnly: "AUDIO ONLY"
        case .minimal: "SIMPLE"
        }
    }

    var symbol: String {
        switch resolved {
        case .cockpit: "airplane"
        case .cinematic: "viewfinder"
        case .simple: "rectangle.grid.1x2"
        case .audioOnly: "moon.stars"
        case .minimal: "rectangle.grid.1x2"
        }
    }
}

enum FocusSessionKind: String, Codable, Sendable {
    case focus
    case breakTime
}

struct FocusSession: Codable, Identifiable, Sendable, Equatable {
    var id: UUID
    var missionID: UUID?
    var startedAt: Date
    var scheduledEndAt: Date
    var pauseStartedAt: Date?
    var accumulatedPausedDuration: TimeInterval
    var configuredDuration: TimeInterval
    var completedAt: Date?
    var pauseCount: Int
    var destination: Destination
    var status: FocusSessionStatus
    var focusRating: FocusRating?
    var displayMode: FocusDisplayMode
    var kind: FocusSessionKind
    var isPomodoro: Bool
    var breakDuration: TimeInterval
    var pomodoroConfiguration: PomodoroConfiguration?
    var currentCycle: Int
    var lastKnownElapsed: TimeInterval
    var lastKnownRemaining: TimeInterval
    var lastKnownProgress: Double

    init(
        id: UUID = UUID(),
        missionID: UUID? = nil,
        startedAt: Date,
        scheduledEndAt: Date,
        pauseStartedAt: Date? = nil,
        accumulatedPausedDuration: TimeInterval = 0,
        configuredDuration: TimeInterval,
        completedAt: Date? = nil,
        pauseCount: Int = 0,
        destination: Destination,
        status: FocusSessionStatus,
        focusRating: FocusRating? = nil,
        displayMode: FocusDisplayMode = .cockpit,
        kind: FocusSessionKind = .focus,
        isPomodoro: Bool = false,
        breakDuration: TimeInterval = 0,
        pomodoroConfiguration: PomodoroConfiguration? = nil,
        currentCycle: Int = 1,
        lastKnownElapsed: TimeInterval = 0,
        lastKnownRemaining: TimeInterval? = nil,
        lastKnownProgress: Double = 0
    ) {
        self.id = id
        self.missionID = missionID
        self.startedAt = startedAt
        self.scheduledEndAt = scheduledEndAt
        self.pauseStartedAt = pauseStartedAt
        self.accumulatedPausedDuration = accumulatedPausedDuration
        self.configuredDuration = configuredDuration
        self.completedAt = completedAt
        self.pauseCount = pauseCount
        self.destination = destination
        self.status = status
        self.focusRating = focusRating
        self.displayMode = displayMode
        self.kind = kind
        self.isPomodoro = isPomodoro
        self.breakDuration = breakDuration
        self.pomodoroConfiguration = pomodoroConfiguration
        self.currentCycle = currentCycle
        self.lastKnownElapsed = lastKnownElapsed
        self.lastKnownRemaining = lastKnownRemaining ?? configuredDuration
        self.lastKnownProgress = lastKnownProgress
    }

    func remainingSeconds(at date: Date) -> TimeInterval {
        if status.isPaused, let pauseStartedAt {
            return max(scheduledEndAt.timeIntervalSince(pauseStartedAt), 0)
        }
        return max(scheduledEndAt.timeIntervalSince(date), 0)
    }

    func elapsedSeconds(at date: Date) -> TimeInterval {
        min(max(configuredDuration - remainingSeconds(at: date), 0), configuredDuration)
    }

    func progress(at date: Date) -> Double {
        guard configuredDuration > 0 else { return 0 }
        return min(max(elapsedSeconds(at: date) / configuredDuration, 0), 1)
    }

    var isValid: Bool {
        configuredDuration > 0 && configuredDuration <= 24 * 60 * 60 && scheduledEndAt >= startedAt
    }
}
