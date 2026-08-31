import Foundation

struct FocusStatisticsSnapshot {
    let todaySeconds: TimeInterval
    let weekSeconds: TimeInterval
    let monthSeconds: TimeInterval
    let totalSeconds: TimeInterval
    let sessionCount: Int
    let completedCount: Int
    let interruptedCount: Int
    let completionRate: Double
    let interruptionRate: Double
    let currentStreak: Int
    let longestStreak: Int
    let averageSeconds: TimeInterval
    let commonDurationMinutes: Int?
    let bestTimeBand: String?
    let favoriteDestination: Destination?
    let completedBreakCount: Int
    let completedPomodoroCount: Int
    let averageBreakSeconds: TimeInterval
}

struct FocusChartPoint: Identifiable {
    let label: String
    let date: Date
    let seconds: TimeInterval
    var id: String { "\(label)-\(date.timeIntervalSinceReferenceDate)" }
}

struct CategoryFocusPoint: Identifiable {
    let label: String
    let value: Double
    var id: String { label }
}

struct RatingDistributionItem: Identifiable {
    let rating: FocusRating
    let count: Int
    var id: FocusRating { rating }
}

struct DestinationAchievement: Identifiable {
    let destination: Destination
    let completedCount: Int
    var id: Destination { destination }
    var isReached: Bool { completedCount > 0 }
    var badgeTitle: String? {
        if completedCount >= 15 { return LocalizedRuntime.text(ja: "航路熟練", en: "Route Master") }
        if completedCount >= 7 { return LocalizedRuntime.text(ja: "継続観測", en: "Steady Observer") }
        if completedCount >= 3 { return LocalizedRuntime.text(ja: "航路確立", en: "Route Established") }
        if completedCount >= 1 { return LocalizedRuntime.text(ja: "初到達", en: "First Arrival") }
        return nil
    }

    var routeStatus: String { badgeTitle ?? LocalizedRuntime.text(ja: "未到達", en: "Not Reached") }

    var rankProgress: Double {
        let bounds = rankBounds
        guard bounds.upper > bounds.lower else { return 1 }
        return min(max(Double(completedCount - bounds.lower) / Double(bounds.upper - bounds.lower), 0), 1)
    }

    var nextMilestoneText: String {
        let bounds = rankBounds
        guard bounds.upper > completedCount else { return LocalizedRuntime.text(ja: "この航路の観測記録を継続中", en: "Continuing observations on this route") }
        return LocalizedRuntime.format(ja: "あと%d回で%@", en: "%2$@ in %1$d more runs", bounds.upper - completedCount, nextRankTitle)
    }

    private var rankBounds: (lower: Int, upper: Int) {
        switch completedCount {
        case ..<1: (0, 1)
        case 1..<3: (1, 3)
        case 3..<7: (3, 7)
        case 7..<15: (7, 15)
        default: (15, 15)
        }
    }

    private var nextRankTitle: String {
        switch completedCount {
        case ..<1: LocalizedRuntime.text(ja: "初到達", en: "First Arrival")
        case 1..<3: LocalizedRuntime.text(ja: "航路確立", en: "Route Established")
        case 3..<7: LocalizedRuntime.text(ja: "継続観測", en: "Steady Observer")
        default: LocalizedRuntime.text(ja: "航路熟練", en: "Route Master")
        }
    }
}

enum FocusStatisticsService {
    static func snapshot(
        records: [MissionRecord],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> FocusStatisticsSnapshot {
        let focus = records.filter(\.isFocusRecord)
        let breaks = records.filter(\.isBreakRecord)
        let today = calendar.dateInterval(of: .day, for: now) ?? DateInterval(start: now, duration: 0)
        let week = calendar.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: now, duration: 0)
        let month = calendar.dateInterval(of: .month, for: now) ?? DateInterval(start: now, duration: 0)
        let completed = focus.filter(\.isCompleted)
        let interrupted = focus.filter { !$0.isCompleted }
        let total = focus.reduce(0) { $0 + max($1.actualSeconds, 0) }
        let commonDuration = Dictionary(grouping: focus, by: \.plannedMinutes)
            .max { lhs, rhs in lhs.value.count < rhs.value.count }?.key
        let favorite = Dictionary(grouping: completed, by: \.destination)
            .max { lhs, rhs in lhs.value.count < rhs.value.count }?.key

        return FocusStatisticsSnapshot(
            todaySeconds: seconds(focus, in: today),
            weekSeconds: seconds(focus, in: week),
            monthSeconds: seconds(focus, in: month),
            totalSeconds: total,
            sessionCount: focus.count,
            completedCount: completed.count,
            interruptedCount: interrupted.count,
            completionRate: rate(completed.count, of: focus.count),
            interruptionRate: rate(interrupted.count, of: focus.count),
            currentStreak: currentStreak(records: completed, now: now, calendar: calendar),
            longestStreak: longestStreak(records: completed, calendar: calendar),
            averageSeconds: focus.isEmpty ? 0 : total / Double(focus.count),
            commonDurationMinutes: commonDuration,
            bestTimeBand: bestTimeBand(records: completed, calendar: calendar),
            favoriteDestination: favorite,
            completedBreakCount: breaks.filter(\.isCompleted).count,
            completedPomodoroCount: completed.filter(\.isPomodoro).count,
            averageBreakSeconds: breaks.isEmpty ? 0 : breaks.reduce(0) { $0 + $1.actualSeconds } / Double(breaks.count)
        )
    }

    static func dailyPoints(
        records: [MissionRecord],
        days: Int = 7,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [FocusChartPoint] {
        let focus = records.filter(\.isFocusRecord)
        let today = calendar.startOfDay(for: now)
        return (0..<max(days, 1)).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today),
                  let end = calendar.date(byAdding: .day, value: 1, to: date) else { return nil }
            let label = date.formatted(.dateTime.weekday(.narrow))
            return FocusChartPoint(label: label, date: date, seconds: seconds(focus, in: DateInterval(start: date, end: end)))
        }
    }

    static func weekdayPoints(records: [MissionRecord], calendar: Calendar = .current) -> [CategoryFocusPoint] {
        let labels = calendar.shortWeekdaySymbols
        let grouped = Dictionary(grouping: records.filter(\.isFocusRecord)) { calendar.component(.weekday, from: $0.effectiveDate) }
        return (1...7).map { weekday in
            CategoryFocusPoint(label: String(labels[weekday - 1].prefix(1)), value: grouped[weekday, default: []].reduce(0) { $0 + $1.actualSeconds / 60 })
        }
    }

    static func timeBandPoints(records: [MissionRecord], calendar: Calendar = .current) -> [CategoryFocusPoint] {
        let bands = [
            LocalizedRuntime.text(ja: "深夜", en: "Late Night"),
            LocalizedRuntime.text(ja: "朝", en: "Morning"),
            LocalizedRuntime.text(ja: "昼", en: "Afternoon"),
            LocalizedRuntime.text(ja: "夕方", en: "Evening"),
            LocalizedRuntime.text(ja: "夜", en: "Night")
        ]
        let grouped = Dictionary(grouping: records.filter(\.isFocusRecord)) { timeBand(for: calendar.component(.hour, from: $0.effectiveDate)) }
        return bands.map { CategoryFocusPoint(label: $0, value: Double(grouped[$0, default: []].count)) }
    }

    static func destinationPoints(records: [MissionRecord]) -> [CategoryFocusPoint] {
        let grouped = Dictionary(grouping: records.filter(\.isFocusRecord), by: \.destination)
        return Destination.allCases.map { CategoryFocusPoint(label: $0.name, value: Double(grouped[$0, default: []].count)) }
    }

    static func ratingDistribution(records: [MissionRecord]) -> [RatingDistributionItem] {
        let rated = records.filter(\.isFocusRecord).compactMap(\.rating).filter { $0 != .skipped }
        let grouped = Dictionary(grouping: rated, by: { $0 })
        return [FocusRating.focused, .somewhat, .distracted].map { RatingDistributionItem(rating: $0, count: grouped[$0, default: []].count) }
    }

    static func achievements(records: [MissionRecord]) -> [DestinationAchievement] {
        let completed = records.filter { $0.isFocusRecord && $0.isCompleted }
        let grouped = Dictionary(grouping: completed, by: \.destination)
        return Destination.allCases.map { DestinationAchievement(destination: $0, completedCount: grouped[$0, default: []].count) }
    }

    static func homeSummary(records: [MissionRecord], now: Date = .now, calendar: Calendar = .current) -> String {
        let focus = records.filter(\.isFocusRecord)
        guard !focus.isEmpty else { return LocalizedRuntime.text(ja: "最初の集中記録がここに要約されます", en: "Your first focus record summary will appear here") }
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now),
              let previousStart = calendar.date(byAdding: .weekOfYear, value: -1, to: week.start) else {
            return LocalizedRuntime.text(ja: "集中記録を蓄積しています", en: "Your focus records are accumulating")
        }
        let current = seconds(focus, in: week)
        let previous = seconds(focus, in: DateInterval(start: previousStart, end: week.start))
        let differenceMinutes = Int(abs(current - previous) / 60)
        if differenceMinutes > 0 {
            return current >= previous
                ? LocalizedRuntime.format(ja: "今週は先週より%d分多く集中しています", en: "You have focused %d minutes more than last week", differenceMinutes)
                : LocalizedRuntime.format(ja: "先週の集中時間まであと%d分です", en: "%d minutes to match last week's focus time", differenceMinutes)
        }
        let snapshot = snapshot(records: records, now: now, calendar: calendar)
        if let band = snapshot.bestTimeBand {
            return LocalizedRuntime.format(ja: "%@の時間帯に集中記録が多い傾向です", en: "You tend to focus most during %1$@", band)
        }
        return LocalizedRuntime.text(ja: "今週も集中記録を積み重ねています", en: "You are steadily building focus time this week")
    }

    static func focusedSeconds(records: [MissionRecord], in interval: DateInterval) -> TimeInterval {
        seconds(records.filter(\.isFocusRecord), in: interval)
    }

    static func currentStreak(records: [MissionRecord], now: Date = .now, calendar: Calendar = .current) -> Int {
        let days = completedDays(records: records, calendar: calendar)
        var cursor = calendar.startOfDay(for: now)
        if !days.contains(cursor), let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) { cursor = yesterday }
        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    static func longestStreak(records: [MissionRecord], calendar: Calendar = .current) -> Int {
        let days = completedDays(records: records, calendar: calendar).sorted()
        guard !days.isEmpty else { return 0 }
        var longest = 1
        var current = 1
        for index in 1..<days.count {
            let difference = calendar.dateComponents([.day], from: days[index - 1], to: days[index]).day ?? 0
            current = difference == 1 ? current + 1 : 1
            longest = max(longest, current)
        }
        return longest
    }

    private static func seconds(_ records: [MissionRecord], in interval: DateInterval) -> TimeInterval {
        records.reduce(0) { $0 + allocatedSeconds(for: $1, in: interval) }
    }

    private static func allocatedSeconds(for record: MissionRecord, in interval: DateInterval) -> TimeInterval {
        let actual = max(record.actualSeconds, 0)
        guard let start = record.startedAt, record.completedAt > start else {
            return interval.contains(record.effectiveDate) ? actual : 0
        }
        let overlapStart = max(start, interval.start)
        let overlapEnd = min(record.completedAt, interval.end)
        guard overlapEnd > overlapStart else { return 0 }
        let wallDuration = record.completedAt.timeIntervalSince(start)
        return actual * overlapEnd.timeIntervalSince(overlapStart) / wallDuration
    }

    private static func rate(_ value: Int, of total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(value) / Double(total)
    }

    private static func completedDays(records: [MissionRecord], calendar: Calendar) -> Set<Date> {
        Set(records.filter { $0.isFocusRecord && $0.isCompleted }.map { calendar.startOfDay(for: $0.effectiveDate) })
    }

    private static func bestTimeBand(records: [MissionRecord], calendar: Calendar) -> String? {
        guard records.count >= 2 else { return nil }
        let grouped = Dictionary(grouping: records) { timeBand(for: calendar.component(.hour, from: $0.effectiveDate)) }
        return grouped.max { lhs, rhs in lhs.value.count < rhs.value.count }?.key
    }

    private static func timeBand(for hour: Int) -> String {
        switch hour {
        case 0..<5: LocalizedRuntime.text(ja: "深夜", en: "Late Night")
        case 5..<11: LocalizedRuntime.text(ja: "朝", en: "Morning")
        case 11..<16: LocalizedRuntime.text(ja: "昼", en: "Afternoon")
        case 16..<19: LocalizedRuntime.text(ja: "夕方", en: "Evening")
        default: LocalizedRuntime.text(ja: "夜", en: "Night")
        }
    }
}

enum WeeklyGoalService {
    static func progress(records: [MissionRecord], goalMinutes: Int, now: Date = .now, calendar: Calendar = .current) -> Double {
        guard goalMinutes > 0,
              let interval = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        let seconds = FocusStatisticsService.focusedSeconds(records: records, in: interval)
        return min(max(seconds / TimeInterval(goalMinutes * 60), 0), 1)
    }
}
