import Foundation

struct RoadmapLeg: Identifiable, Equatable {
    let destination: Destination
    let requiredSeconds: TimeInterval
    var id: Destination { destination }
}

enum RoadmapRoute {
    static let legs: [RoadmapLeg] = [
        RoadmapLeg(destination: .moon, requiredSeconds: 50 * 60 * 60),
        RoadmapLeg(destination: .mars, requiredSeconds: 100 * 60 * 60),
        RoadmapLeg(destination: .jupiter, requiredSeconds: 100 * 60 * 60),
        RoadmapLeg(destination: .saturn, requiredSeconds: 100 * 60 * 60),
        RoadmapLeg(destination: .uranus, requiredSeconds: 100 * 60 * 60),
        RoadmapLeg(destination: .neptune, requiredSeconds: 100 * 60 * 60),
        RoadmapLeg(destination: .pluto, requiredSeconds: 100 * 60 * 60),
        RoadmapLeg(destination: .mercury, requiredSeconds: 100 * 60 * 60),
        RoadmapLeg(destination: .venus, requiredSeconds: 100 * 60 * 60)
    ]

    static let totalSeconds = legs.reduce(0) { $0 + $1.requiredSeconds }
}

struct RoadmapProgress {
    let totalSeconds: TimeInterval

    private var resolved: (index: Int, elapsed: TimeInterval) {
        var remaining = max(totalSeconds, 0)
        for (index, leg) in RoadmapRoute.legs.enumerated() {
            if remaining < leg.requiredSeconds { return (index, remaining) }
            remaining -= leg.requiredSeconds
        }
        return (RoadmapRoute.legs.count - 1, RoadmapRoute.legs.last?.requiredSeconds ?? 1)
    }

    var legIndex: Int { resolved.index }
    var leg: RoadmapLeg { RoadmapRoute.legs[legIndex] }
    var target: Destination { leg.destination }
    var origin: Destination? { legIndex == 0 ? nil : RoadmapRoute.legs[legIndex - 1].destination }
    var originName: String { origin?.name ?? String(localized: "common.earth", defaultValue: "地球") }
    var legFraction: Double { min(max(resolved.elapsed / leg.requiredSeconds, 0), 1) }
    var remainingSeconds: TimeInterval { max(leg.requiredSeconds - resolved.elapsed, 0) }
    var completedDestinationCount: Int {
        if totalSeconds >= RoadmapRoute.totalSeconds { return RoadmapRoute.legs.count }
        return legIndex
    }
    var isComplete: Bool { totalSeconds >= RoadmapRoute.totalSeconds }
}
