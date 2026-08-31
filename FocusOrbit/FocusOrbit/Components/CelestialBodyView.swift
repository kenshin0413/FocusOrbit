import SwiftUI

enum CelestialBodyKind {
    case earth
    case destination(Destination)
}

struct CelestialBodyView: View {
    let kind: CelestialBodyKind
    var rotationSpeed: Double = 0

    var body: some View {
        Group {
            switch kind {
            case .earth:
                roundBody(name: "EarthNASA", accent: .cyan)
            case let .destination(destination):
                switch destination {
                case .moon: spaceImage(name: "MoonPhotoNASA", accent: destination.accent, scale: 1.12)
                case .mercury: spaceImage(name: "MercuryNASA", accent: destination.accent, scale: 1.12)
                case .venus: spaceImage(name: "VenusNASA", accent: destination.accent, scale: 1.12)
                case .mars: roundBody(name: "MarsNASA", accent: destination.accent)
                case .jupiter: spaceImage(name: "JupiterNASA", accent: destination.accent, scale: 1.12, clipsEdges: true)
                case .saturn: spaceImage(name: "SaturnNASA", accent: destination.accent, scale: 1.12)
                case .uranus: spaceImage(name: "UranusNASA", accent: destination.accent, scale: 1.12)
                case .neptune: spaceImage(name: "NeptuneNASA", accent: destination.accent, scale: 1.12)
                case .pluto: plutoBody(accent: destination.accent)
                case .station: spaceImage(name: "StationNASA", accent: destination.accent, scale: 1.12)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .allowsHitTesting(false)
    }

    private func plutoBody(accent: Color) -> some View {
        Image("PlutoNASA")
            .resizable()
            .scaledToFit()
            .scaleEffect(1.28)
            .shadow(color: accent.opacity(0.22), radius: 12)
    }

    private func roundBody(name: String, accent: Color, scale: CGFloat = 1) -> some View {
        ZStack {
            Image(name).resizable().scaledToFill().scaleEffect(scale)
            Circle().fill(LinearGradient(colors: [.white.opacity(0.035), .clear, .black.opacity(0.48)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().stroke(.white.opacity(0.10), lineWidth: 0.5)
        }
        .clipShape(Circle())
        .shadow(color: accent.opacity(0.24), radius: 12)
    }

    @ViewBuilder
    private func spaceImage(name: String, accent: Color, scale: CGFloat, clipsEdges: Bool = false) -> some View {
        if clipsEdges {
            Image(name)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .clipped()
                .shadow(color: accent.opacity(0.2), radius: 12)
        } else {
            Image(name)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .shadow(color: accent.opacity(0.2), radius: 12)
        }
    }
}
