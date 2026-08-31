import Foundation
import SwiftData

@Model final class RoadmapFocusRecord {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var completedAt: Date
    var focusedSeconds: Double
    var pauseCount: Int

    init(
        id: UUID = UUID(),
        startedAt: Date,
        completedAt: Date,
        focusedSeconds: TimeInterval,
        pauseCount: Int
    ) {
        self.id = id
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.focusedSeconds = focusedSeconds
        self.pauseCount = pauseCount
    }
}

enum RoadmapStorageService {
    static func totalSeconds(_ records: [RoadmapFocusRecord]) -> TimeInterval {
        records.reduce(0) { $0 + max($1.focusedSeconds, 0) }
    }

    static func todaySeconds(
        _ records: [RoadmapFocusRecord],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> TimeInterval {
        guard let today = calendar.dateInterval(of: .day, for: now) else { return 0 }
        return seconds(records, in: today)
    }

    static func seconds(
        _ records: [RoadmapFocusRecord],
        in interval: DateInterval
    ) -> TimeInterval {
        records.reduce(0) { $0 + allocatedSeconds(for: $1, in: interval) }
    }

    private static func allocatedSeconds(for record: RoadmapFocusRecord, in interval: DateInterval) -> TimeInterval {
        let actual = max(record.focusedSeconds, 0)
        guard record.completedAt > record.startedAt else {
            return interval.contains(record.completedAt) ? actual : 0
        }
        let overlapStart = max(record.startedAt, interval.start)
        let overlapEnd = min(record.completedAt, interval.end)
        guard overlapEnd > overlapStart else { return 0 }
        let wallDuration = record.completedAt.timeIntervalSince(record.startedAt)
        return actual * overlapEnd.timeIntervalSince(overlapStart) / wallDuration
    }
}
