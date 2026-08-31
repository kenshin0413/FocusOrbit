import SwiftUI

enum Destination: String, Codable, CaseIterable, Identifiable, Sendable {
    case moon, station, mercury, venus, mars, jupiter, saturn, uranus, neptune, pluto
    var id: String { rawValue }
    var name: String {
        switch self {
        case .moon: LocalizedRuntime.text(ja: "月", en: "Moon")
        case .station: LocalizedRuntime.text(ja: "宇宙ステーション", en: "Space Station")
        case .mercury: LocalizedRuntime.text(ja: "水星", en: "Mercury")
        case .venus: LocalizedRuntime.text(ja: "金星", en: "Venus")
        case .mars: LocalizedRuntime.text(ja: "火星", en: "Mars")
        case .jupiter: LocalizedRuntime.text(ja: "木星", en: "Jupiter")
        case .saturn: LocalizedRuntime.text(ja: "土星", en: "Saturn")
        case .uranus: LocalizedRuntime.text(ja: "天王星", en: "Uranus")
        case .neptune: LocalizedRuntime.text(ja: "海王星", en: "Neptune")
        case .pluto: LocalizedRuntime.text(ja: "冥王星", en: "Pluto")
        }
    }
    var englishName: String {
        switch self {
        case .moon: "MOON"
        case .station: "SPACE STATION"
        case .mercury: "MERCURY"
        case .venus: "VENUS"
        case .mars: "MARS"
        case .jupiter: "JUPITER"
        case .saturn: "SATURN"
        case .uranus: "URANUS"
        case .neptune: "NEPTUNE"
        case .pluto: "PLUTO"
        }
    }
    var imageName: String {
        switch self {
        case .moon: "MoonPhotoNASA"
        case .station: "StationNASA"
        case .mercury: "MercuryNASA"
        case .venus: "VenusNASA"
        case .mars: "MarsNASA"
        case .jupiter: "JupiterNASA"
        case .saturn: "SaturnNASA"
        case .uranus: "UranusNASA"
        case .neptune: "NeptuneNASA"
        case .pluto: "PlutoNASA"
        }
    }
    var symbol: String {
        switch self { case .moon: "moon.fill"; case .station: "square.3.layers.3d"; case .mercury: "circle.lefthalf.filled"; case .venus: "circle.fill"; case .mars: "circle.fill"; case .jupiter: "circle.dotted"; case .saturn: "circle.hexagongrid.fill"; case .uranus: "circle.fill"; case .neptune: "circle.fill"; case .pluto: "circle.fill" }
    }
    var distanceKilometers: Double {
        switch self { case .moon: 384_400; case .station: 408; case .mercury: 91_700_000; case .venus: 41_400_000; case .mars: 225_000_000; case .jupiter: 778_500_000; case .saturn: 1_434_000_000; case .uranus: 2_871_000_000; case .neptune: 4_495_000_000; case .pluto: 5_906_000_000 }
    }
    var finalApproachKilometers: Double {
        switch self {
        case .moon, .mars, .pluto: 18
        case .station: 0.12
        case .mercury, .venus, .jupiter, .saturn, .uranus, .neptune: 12_000
        }
    }
    var accent: Color {
        switch self {
        case .moon: Color(red: 0.72, green: 0.78, blue: 0.85)
        case .station: Color(red: 0.45, green: 0.78, blue: 0.95)
        case .mercury: Color(red: 0.70, green: 0.66, blue: 0.60)
        case .venus: Color(red: 0.93, green: 0.76, blue: 0.48)
        case .mars: Color(red: 0.92, green: 0.47, blue: 0.29)
        case .jupiter: Color(red: 0.84, green: 0.67, blue: 0.48)
        case .saturn: Color(red: 0.88, green: 0.75, blue: 0.54)
        case .uranus: Color(red: 0.57, green: 0.86, blue: 0.91)
        case .neptune: Color(red: 0.31, green: 0.49, blue: 0.95)
        case .pluto: Color(red: 0.72, green: 0.58, blue: 0.47)
        }
    }
    var transitMessages: [String] {
        switch self {
        case .moon: [LocalizedRuntime.text(ja: "地球低軌道を離脱", en: "Departing low Earth orbit"), LocalizedRuntime.text(ja: "月軌道へ進入", en: "Entering lunar orbit"), LocalizedRuntime.text(ja: "月とのリンクを確立", en: "Establishing lunar link")]
        case .station: [LocalizedRuntime.text(ja: "ランデブー軌道へ移行", en: "Transferring to rendezvous orbit"), LocalizedRuntime.text(ja: "ステーションを視認", en: "Station in visual range"), LocalizedRuntime.text(ja: "ドッキング経路を確認", en: "Docking approach confirmed")]
        case .mercury: [LocalizedRuntime.text(ja: "内惑星航路へ移行", en: "Transferring to inner-planet route"), LocalizedRuntime.text(ja: "太陽風を観測", en: "Observing solar wind"), LocalizedRuntime.text(ja: "水星周回軌道を確認", en: "Mercury orbital track confirmed")]
        case .venus: [LocalizedRuntime.text(ja: "内惑星航路へ移行", en: "Transferring to inner-planet route"), LocalizedRuntime.text(ja: "金星の雲層を視認", en: "Venus cloud layer in sight"), LocalizedRuntime.text(ja: "金星周回軌道へ進入", en: "Entering Venus orbit")]
        case .mars: [LocalizedRuntime.text(ja: "月軌道を通過", en: "Passing lunar orbit"), LocalizedRuntime.text(ja: "小惑星帯へ進入", en: "Entering the asteroid belt"), LocalizedRuntime.text(ja: "火星軌道を確認", en: "Mars orbital track confirmed")]
        case .jupiter: [LocalizedRuntime.text(ja: "火星軌道を通過", en: "Passing Mars orbit"), LocalizedRuntime.text(ja: "小惑星帯を通過", en: "Crossing the asteroid belt"), LocalizedRuntime.text(ja: "木星圏へ進入", en: "Entering Jovian space")]
        case .saturn: [LocalizedRuntime.text(ja: "小惑星帯を通過", en: "Crossing the asteroid belt"), LocalizedRuntime.text(ja: "木星を通過", en: "Passing Jupiter"), LocalizedRuntime.text(ja: "土星の環を確認", en: "Saturn's rings confirmed")]
        case .uranus: [LocalizedRuntime.text(ja: "土星軌道を通過", en: "Passing Saturn orbit"), LocalizedRuntime.text(ja: "外惑星航路を巡航", en: "Cruising the outer-planet route"), LocalizedRuntime.text(ja: "天王星圏へ進入", en: "Entering Uranian space")]
        case .neptune: [LocalizedRuntime.text(ja: "天王星軌道を通過", en: "Passing Uranus orbit"), LocalizedRuntime.text(ja: "太陽圏外縁へ接近", en: "Approaching the outer heliosphere"), LocalizedRuntime.text(ja: "海王星圏へ進入", en: "Entering Neptunian space")]
        case .pluto: [LocalizedRuntime.text(ja: "海王星軌道を通過", en: "Passing Neptune orbit"), LocalizedRuntime.text(ja: "カイパーベルトを巡航", en: "Cruising the Kuiper belt"), LocalizedRuntime.text(ja: "冥王星を視認", en: "Pluto in visual range")]
        }
    }
}

extension Destination {
    static let roadmapDestinations: [Destination] = [
        .moon, .mars, .jupiter, .saturn, .uranus, .neptune, .pluto, .mercury, .venus
    ]

    var isOrbitalDestination: Bool {
        switch self {
        case .moon, .station, .mars, .pluto: false
        case .mercury, .venus, .jupiter, .saturn, .uranus, .neptune: true
        }
    }

    var isSurfaceDestination: Bool {
        switch self {
        case .moon, .mars, .pluto: true
        default: false
        }
    }

    var isOuterOrbitalDestination: Bool {
        switch self {
        case .jupiter, .saturn, .uranus, .neptune: true
        default: false
        }
    }

    var hasWideRings: Bool { self == .saturn }
}
