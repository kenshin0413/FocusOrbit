import Foundation
import SwiftData

enum FocusRating: String, Codable, CaseIterable, Identifiable, Sendable {
    case focused, somewhat, distracted, skipped
    var id: String { rawValue }
    var title: String {
        switch self {
        case .focused: LocalizedRuntime.text(ja: "集中できた", en: "Focused")
        case .somewhat: LocalizedRuntime.text(ja: "まあまあ集中できた", en: "Somewhat Focused")
        case .distracted: LocalizedRuntime.text(ja: "あまり集中できなかった", en: "Distracted")
        case .skipped: LocalizedRuntime.text(ja: "スキップ", en: "Skipped")
        }
    }
}

enum MissionRecordKind: String, Codable, CaseIterable, Sendable {
    case focus
    case breakTime
}

@Model final class MissionRecord {
    @Attribute(.unique) var id: UUID
    var missionNumber: String
    var focusTitle: String
    var destinationRaw: String
    var plannedMinutes: Int
    var actualSeconds: Double
    var completedAt: Date
    var isCompleted: Bool
    var distanceKilometers: Double
    var ratingRaw: String?
    var pauseCount: Int = 0
    var displayModeRaw: String = FocusDisplayMode.cockpit.rawValue
    var recordKindRaw: String = MissionRecordKind.focus.rawValue
    var sessionID: UUID?
    var startedAt: Date?
    var isPomodoro: Bool = false
    var pomodoroCycle: Int = 1
    var wasAutomaticallyStarted: Bool = false

    init(
        mission: Mission,
        actualSeconds: Double,
        completed: Bool,
        pauseCount: Int = 0,
        displayMode: FocusDisplayMode = .cockpit,
        kind: MissionRecordKind = .focus,
        session: FocusSession? = nil,
        wasAutomaticallyStarted: Bool = false
    ) {
        id = UUID(); missionNumber = mission.missionNumber; focusTitle = mission.focusTitle; destinationRaw = mission.destinationRaw
        plannedMinutes = mission.durationMinutes; self.actualSeconds = actualSeconds; completedAt = .now; isCompleted = completed
        distanceKilometers = mission.destination.distanceKilometers * min(max(actualSeconds / mission.totalSeconds, 0), 1)
        self.pauseCount = pauseCount
        displayModeRaw = displayMode.resolved.rawValue
        recordKindRaw = kind.rawValue
        sessionID = session?.id
        startedAt = session?.startedAt
        isPomodoro = mission.isPomodoro || session?.isPomodoro == true
        pomodoroCycle = session?.currentCycle ?? 1
        self.wasAutomaticallyStarted = wasAutomaticallyStarted
    }
    var destination: Destination { Destination(rawValue: destinationRaw) ?? .moon }
    var rating: FocusRating? {
        get { ratingRaw.flatMap(FocusRating.init(rawValue:)) }
        set { ratingRaw = newValue?.rawValue }
    }
    var displayMode: FocusDisplayMode { FocusDisplayMode(rawValue: displayModeRaw)?.resolved ?? .cockpit }
    var kind: MissionRecordKind { MissionRecordKind(rawValue: recordKindRaw) ?? .focus }
    var isFocusRecord: Bool { kind == .focus }
    var isBreakRecord: Bool { kind == .breakTime }
    var effectiveDate: Date { startedAt ?? completedAt }
}
