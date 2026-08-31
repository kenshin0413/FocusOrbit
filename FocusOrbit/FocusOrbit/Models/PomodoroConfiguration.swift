import Foundation

struct PomodoroConfiguration: Codable, Sendable, Equatable {
    var focusDuration: TimeInterval
    var shortBreakDuration: TimeInterval
    var cycleCount: Int
    var longBreakDuration: TimeInterval?
    var longBreakEvery: Int?
    var automaticallyStartBreak: Bool
    var automaticallyStartNextFocus: Bool

    static let classic = PomodoroConfiguration(
        focusDuration: 25 * 60,
        shortBreakDuration: 5 * 60,
        cycleCount: 4,
        longBreakDuration: 15 * 60,
        longBreakEvery: 4,
        automaticallyStartBreak: false,
        automaticallyStartNextFocus: false
    )

    static let extended = PomodoroConfiguration(
        focusDuration: 50 * 60,
        shortBreakDuration: 10 * 60,
        cycleCount: 4,
        longBreakDuration: 20 * 60,
        longBreakEvery: 4,
        automaticallyStartBreak: false,
        automaticallyStartNextFocus: false
    )

    func breakDuration(after cycle: Int) -> TimeInterval {
        if let longBreakEvery, let longBreakDuration, cycle.isMultiple(of: longBreakEvery) {
            return longBreakDuration
        }
        return shortBreakDuration
    }
}
