import Foundation
import SwiftData

private enum AppSettingsHistoryCodec {
    static func decodeStrings(_ rawValue: String) -> [String] {
        guard let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return decoded
    }

    static func encodeStrings(_ values: [String]) -> String {
        guard let data = try? JSONEncoder().encode(values),
              let encoded = String(data: data, encoding: .utf8) else { return "[]" }
        return encoded
    }

    static func decodeInts(_ rawValue: String) -> [Int] {
        guard let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([Int].self, from: data) else { return [] }
        return decoded
    }

    static func encodeInts(_ values: [Int]) -> String {
        guard let data = try? JSONEncoder().encode(values),
              let encoded = String(data: data, encoding: .utf8) else { return "[]" }
        return encoded
    }
}

@Model final class CrewProfile {
    @Attribute(.unique) var id: UUID
    var crewName: String
    var crewID: String
    var firstUseDate: Date
    init(crewName: String = "KENSHIN") {
        id = UUID(); self.crewName = crewName; crewID = "FO-\(Int.random(in: 1000...9999))"; firstUseDate = .now
    }
}

@Model final class AppSettings {
    @Attribute(.unique) var id: UUID
    var ambientSoundEnabled: Bool
    var completionNotificationEnabled: Bool
    var voiceAnnouncementsEnabled: Bool = true
    var hasCompletedIntroduction: Bool = false
    var detailedFlightDataEnabled: Bool = false
    var darkRoomModeEnabled: Bool = false
    var hapticsEnabled: Bool = true
    var flightDisplayModeRaw: String = FocusDisplayMode.cockpit.rawValue
    var lastDurationMinutes: Int = 25
    var lastDestinationRaw: String = Destination.moon.rawValue
    var hasCompletedFullLaunch: Bool = false
    var shortenLaunchSequence: Bool = true
    var skipLaunchSequence: Bool = false
    var pomodoroFocusMinutes: Int = 25
    var pomodoroBreakMinutes: Int = 5
    var pomodoroCycles: Int = 4
    var pomodoroLongBreakMinutes: Int = 15
    var pomodoroLongBreakEvery: Int = 4
    var pomodoroAutoStartBreak: Bool = false
    var pomodoroAutoStartFocus: Bool = false
    var weeklyFocusGoalMinutes: Int = 150
    var weeklyGoalEnabled: Bool = true
    var hasRequestedTrackingPermission: Bool = false
    var focusTitleHistoryRaw: String = "[]"
    var durationHistoryRaw: String = "[]"

    init() {
        id = UUID()
        ambientSoundEnabled = true
        completionNotificationEnabled = true
        voiceAnnouncementsEnabled = true
        hasCompletedIntroduction = false
        detailedFlightDataEnabled = false
        darkRoomModeEnabled = false
        hapticsEnabled = true
        flightDisplayModeRaw = FocusDisplayMode.cockpit.rawValue
        lastDurationMinutes = 25
        lastDestinationRaw = Destination.moon.rawValue
        weeklyFocusGoalMinutes = 150
        weeklyGoalEnabled = true
        hasRequestedTrackingPermission = false
        focusTitleHistoryRaw = "[]"
        durationHistoryRaw = "[]"
    }

    var flightDisplayMode: FocusDisplayMode {
        get { FocusDisplayMode(rawValue: flightDisplayModeRaw)?.resolved ?? .cockpit }
        set { flightDisplayModeRaw = newValue.resolved.rawValue }
    }

    var lastDestination: Destination {
        get { Destination(rawValue: lastDestinationRaw) ?? .moon }
        set { lastDestinationRaw = newValue.rawValue }
    }

    var focusTitleHistory: [String] {
        get { AppSettingsHistoryCodec.decodeStrings(focusTitleHistoryRaw) }
        set { focusTitleHistoryRaw = AppSettingsHistoryCodec.encodeStrings(Array(newValue.prefix(12))) }
    }

    var durationHistoryMinutes: [Int] {
        get { AppSettingsHistoryCodec.decodeInts(durationHistoryRaw) }
        set { durationHistoryRaw = AppSettingsHistoryCodec.encodeInts(Array(newValue.prefix(12))) }
    }

    func rememberFocusTitle(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var updated = focusTitleHistory.filter { $0 != trimmed }
        updated.insert(trimmed, at: 0)
        focusTitleHistory = updated
    }

    func rememberDurationMinutes(_ minutes: Int) {
        let sanitized = max(minutes, 1)
        var updated = durationHistoryMinutes.filter { $0 != sanitized }
        updated.insert(sanitized, at: 0)
        durationHistoryMinutes = updated
    }
}
