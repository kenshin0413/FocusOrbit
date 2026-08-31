#if canImport(ActivityKit)
import ActivityKit
import Foundation

struct FocusOrbitActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var scheduledEndAt: Date
        var remainingAtPause: TimeInterval
        var isPaused: Bool
        var progress: Double
        var phaseJapanese: String
        var phaseEnglish: String
    }

    var sessionID: UUID
    var destinationName: String
    var destinationEnglishName: String
}
#endif
