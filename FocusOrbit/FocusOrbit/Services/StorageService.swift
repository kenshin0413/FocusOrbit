import Foundation

struct DailyFocus: Identifiable {
    let date: Date
    let seconds: TimeInterval
    var id: Date { date }
}

enum StorageService {
    static func focusRecords(_ records: [MissionRecord]) -> [MissionRecord] { records.filter(\.isFocusRecord) }
    static func totalSeconds(_ records: [MissionRecord]) -> TimeInterval { focusRecords(records).reduce(0) { $0 + $1.actualSeconds } }
    static func completedCount(_ records: [MissionRecord]) -> Int { focusRecords(records).filter(\.isCompleted).count }
    static func seconds(_ records: [MissionRecord], in interval: DateInterval) -> TimeInterval {
        FocusStatisticsService.focusedSeconds(records: records, in: interval)
    }
    static func currentWeek() -> DateInterval { Calendar.current.dateInterval(of: .weekOfYear, for: .now) ?? DateInterval(start: .now, duration: 0) }
    static func previousWeek() -> DateInterval {
        let current = currentWeek()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: current.start) ?? current.start
        return DateInterval(start: start, end: current.start)
    }
    static func currentMonth() -> DateInterval { Calendar.current.dateInterval(of: .month, for: .now) ?? DateInterval(start: .now, duration: 0) }
    static func todaySeconds(_ records: [MissionRecord], now: Date = .now) -> TimeInterval {
        let calendar = Calendar.current
        guard let today = calendar.dateInterval(of: .day, for: now) else { return 0 }
        return FocusStatisticsService.focusedSeconds(records: records, in: today)
    }
    static func lastSevenDays(_ records: [MissionRecord]) -> [DailyFocus] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (-6...0).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: today),
                  let next = calendar.date(byAdding: .day, value: 1, to: date) else { return nil }
            return DailyFocus(date: date, seconds: seconds(records, in: DateInterval(start: date, end: next)))
        }
    }
    static func streak(_ records: [MissionRecord]) -> Int {
        let calendar = Calendar.current; let days = Set(focusRecords(records).filter(\.isCompleted).map { calendar.startOfDay(for: $0.effectiveDate) })
        var cursor = calendar.startOfDay(for: .now)
        if !days.contains(cursor), let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) { cursor = yesterday }
        var count = 0
        while days.contains(cursor) { count += 1; guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }; cursor = previous }
        return count
    }
}
