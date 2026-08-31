import CoreGraphics
import Foundation

enum MissionVisualGeometry {
    static let arrivalSequenceDuration: TimeInterval = 5.8

    static func arrivalStartProgress(totalSeconds: TimeInterval) -> Double {
        guard totalSeconds > 0 else { return 1 }
        return max(0, 1 - arrivalSequenceDuration / totalSeconds)
    }

    static func arrivalProgress(missionProgress: Double, totalSeconds: TimeInterval) -> Double {
        let start = arrivalStartProgress(totalSeconds: totalSeconds)
        guard start < 1 else { return missionProgress >= 1 ? 1 : 0 }
        return min(max((missionProgress - start) / (1 - start), 0), 1)
    }

    static func earthWidth(screenWidth: CGFloat, progress: Double) -> CGFloat {
        let departure = eased(min(max(progress / 0.58, 0), 1))
        return max(52, screenWidth * CGFloat(0.87 - departure * 0.68))
    }

    static func earthY(progress: Double) -> CGFloat {
        let departure = eased(min(max(progress / 0.58, 0), 1))
        return CGFloat(0.75 + departure * 0.08)
    }

    static func earthOpacity(progress: Double, destination: Destination) -> Double {
        return max(0, 1 - progress / 0.62)
    }

    static func destinationWidth(_ destination: Destination, progress: Double) -> CGFloat {
        let start: Double = destination.hasWideRings ? 58 : 32
        let end: Double
        switch destination {
        case .moon, .mercury, .venus, .mars, .pluto: end = 250
        case .station: end = 280
        case .jupiter, .uranus, .neptune: end = 300
        case .saturn: end = 340
        }
        return CGFloat(start + (end - start) * eased(min(max(progress, 0), 1)))
    }

    static func destinationY(_ destination: Destination, progress: Double) -> CGFloat {
        let settle = eased(min(max(progress / 0.16, 0), 1))
        return CGFloat(0.33 + (destination == .station ? 0.025 : 0) + settle * 0.012)
    }

    static func eased(_ value: Double) -> Double {
        value * value * (3 - 2 * value)
    }
}
