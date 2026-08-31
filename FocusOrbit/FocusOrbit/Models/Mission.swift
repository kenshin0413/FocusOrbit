import Foundation
import SwiftData

enum MissionStatus: String, Codable { case ready, launching, flying, paused, completed, interrupted }

@Model final class Mission {
    @Attribute(.unique) var id: UUID
    var missionNumber: String
    var focusTitle: String
    var durationMinutes: Int
    var destinationRaw: String
    var statusRaw: String
    var createdAt: Date
    var startDate: Date?
    var expectedEndDate: Date?
    var pausedRemainingSeconds: Double?
    var isPomodoro: Bool = false
    var breakDurationMinutes: Int = 5
    var pomodoroCycles: Int = 1
    var longBreakDurationMinutes: Int = 15
    var longBreakEvery: Int = 4
    var automaticallyStartBreak: Bool = false
    var automaticallyStartNextFocus: Bool = false

    init(
        id: UUID = UUID(),
        missionNumber: String,
        focusTitle: String,
        durationMinutes: Int,
        destination: Destination,
        pomodoro: PomodoroConfiguration? = nil
    ) {
        self.id = id; self.missionNumber = missionNumber; self.focusTitle = focusTitle; self.durationMinutes = durationMinutes
        destinationRaw = destination.rawValue; statusRaw = MissionStatus.ready.rawValue; createdAt = .now
        if let pomodoro {
            isPomodoro = true
            breakDurationMinutes = max(Int(pomodoro.shortBreakDuration / 60), 1)
            pomodoroCycles = pomodoro.cycleCount
            longBreakDurationMinutes = max(Int((pomodoro.longBreakDuration ?? 0) / 60), 0)
            longBreakEvery = pomodoro.longBreakEvery ?? 4
            automaticallyStartBreak = pomodoro.automaticallyStartBreak
            automaticallyStartNextFocus = pomodoro.automaticallyStartNextFocus
        }
    }
    var destination: Destination {
        get { Destination(rawValue: destinationRaw) ?? .moon }
        set { destinationRaw = newValue.rawValue }
    }
    var status: MissionStatus {
        get { MissionStatus(rawValue: statusRaw) ?? .ready }
        set { statusRaw = newValue.rawValue }
    }
    var totalSeconds: TimeInterval { TimeInterval(durationMinutes * 60) }
    var pomodoroConfiguration: PomodoroConfiguration? {
        guard isPomodoro else { return nil }
        return PomodoroConfiguration(
            focusDuration: totalSeconds,
            shortBreakDuration: TimeInterval(breakDurationMinutes * 60),
            cycleCount: pomodoroCycles,
            longBreakDuration: longBreakDurationMinutes > 0 ? TimeInterval(longBreakDurationMinutes * 60) : nil,
            longBreakEvery: longBreakDurationMinutes > 0 ? longBreakEvery : nil,
            automaticallyStartBreak: automaticallyStartBreak,
            automaticallyStartNextFocus: automaticallyStartNextFocus
        )
    }
}
