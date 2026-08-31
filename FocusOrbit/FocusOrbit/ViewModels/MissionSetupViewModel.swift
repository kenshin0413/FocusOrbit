import Foundation
import Observation

enum PomodoroPreset: String, CaseIterable, Identifiable {
    case classic, extended, custom
    var id: String { rawValue }
    var title: String {
        switch self {
        case .classic: LocalizedRuntime.text(ja: "25分＋5分", en: "25 min + 5 min")
        case .extended: LocalizedRuntime.text(ja: "50分＋10分", en: "50 min + 10 min")
        case .custom: LocalizedRuntime.text(ja: "カスタム", en: "Custom")
        }
    }
}

@MainActor @Observable
final class MissionSetupViewModel {
    var focusTitle = ""
    var durationMinutes: Int
    var destination: Destination
    var usesPomodoro = false
    var pomodoroPreset: PomodoroPreset = .classic
    var breakMinutes = 5
    var cycleCount = 4
    var longBreakEnabled = true
    var longBreakMinutes = 15
    var longBreakEvery = 4
    var automaticallyStartBreak = false
    var automaticallyStartNextFocus = false

    let titleHistory: [String]
    let durationHistory: [Int]
    var canCreate: Bool { !focusTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    init(
        draft: MissionDraft? = nil,
        lastDuration: Int = 25,
        lastDestination: Destination = .moon,
        titleHistory: [String] = [],
        durationHistory: [Int] = []
    ) {
        self.titleHistory = titleHistory
        self.durationHistory = durationHistory
        durationMinutes = max(lastDuration, 1)
        destination = lastDestination
        guard let draft else { return }
        focusTitle = draft.focusTitle
        durationMinutes = draft.durationMinutes
        destination = draft.destination
    }

    func applyPomodoroPreset(_ preset: PomodoroPreset) {
        pomodoroPreset = preset
        switch preset {
        case .classic:
            durationMinutes = 25; breakMinutes = 5; cycleCount = 4; longBreakEnabled = true; longBreakMinutes = 15
        case .extended:
            durationMinutes = 50; breakMinutes = 10; cycleCount = 4; longBreakEnabled = true; longBreakMinutes = 20
        case .custom:
            break
        }
    }

    var pomodoroConfiguration: PomodoroConfiguration? {
        guard usesPomodoro else { return nil }
        return PomodoroConfiguration(
            focusDuration: TimeInterval(durationMinutes * 60),
            shortBreakDuration: TimeInterval(breakMinutes * 60),
            cycleCount: cycleCount,
            longBreakDuration: longBreakEnabled ? TimeInterval(longBreakMinutes * 60) : nil,
            longBreakEvery: longBreakEnabled ? longBreakEvery : nil,
            automaticallyStartBreak: automaticallyStartBreak,
            automaticallyStartNextFocus: automaticallyStartNextFocus
        )
    }
}
