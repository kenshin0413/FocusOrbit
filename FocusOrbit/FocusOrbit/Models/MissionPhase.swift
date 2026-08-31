import Foundation

enum MissionPhase: String, Codable, CaseIterable, Sendable {
    case launch
    case orbitDeparture
    case cruising
    case approaching
    case decelerating
    case atmosphereEntry
    case surfaceApproach
    case landingPreparation
    case docking
    case orbitalInsertion
    case landed

    var japaneseTitle: String {
        switch self {
        case .launch: String(localized: "phase.launch", defaultValue: "発進")
        case .orbitDeparture: String(localized: "phase.orbit_departure", defaultValue: "地球軌道離脱")
        case .cruising: String(localized: "phase.cruising", defaultValue: "巡航中")
        case .approaching: String(localized: "phase.approaching", defaultValue: "接近中")
        case .decelerating: String(localized: "phase.decelerating", defaultValue: "減速開始")
        case .atmosphereEntry: String(localized: "phase.atmosphere_entry", defaultValue: "大気圏進入")
        case .surfaceApproach: String(localized: "phase.surface_approach", defaultValue: "地表接近")
        case .landingPreparation: String(localized: "phase.landing_preparation", defaultValue: "着陸準備")
        case .docking: String(localized: "phase.docking", defaultValue: "ドッキング接近")
        case .orbitalInsertion: String(localized: "phase.orbital_insertion", defaultValue: "周回軌道投入")
        case .landed: String(localized: "mission.complete", defaultValue: "ミッション完了")
        }
    }

    var englishTitle: String {
        switch self {
        case .launch: "LAUNCH"
        case .orbitDeparture: "ORBIT DEPARTURE"
        case .cruising: "CRUISING"
        case .approaching: "APPROACHING"
        case .decelerating: "DECELERATING"
        case .atmosphereEntry: "ATMOSPHERE ENTRY"
        case .surfaceApproach: "SURFACE APPROACH"
        case .landingPreparation: "LANDING PREPARATION"
        case .docking: "DOCKING"
        case .orbitalInsertion: "ORBITAL INSERTION"
        case .landed: "MISSION COMPLETE"
        }
    }

    static func resolve(progress: Double, destination: Destination, completed: Bool = false) -> MissionPhase {
        if completed || progress >= 1 { return .landed }
        if progress < 0.05 { return .launch }
        if progress < 0.15 { return .orbitDeparture }
        if progress < 0.75 { return .cruising }
        if progress < 0.90 { return .approaching }
        if progress < 0.94 { return .decelerating }
        if destination == .station { return .docking }
        if destination.isOrbitalDestination { return .orbitalInsertion }
        if progress < 0.97 { return .atmosphereEntry }
        if progress < 0.99 { return .surfaceApproach }
        return .landingPreparation
    }
}
