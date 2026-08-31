import SwiftUI

struct DestinationSelectView: View {
    @Binding var selection: Destination
    let durationMinutes: Int
    var visitedDestinations: Set<Destination> = []
    var completedCounts: [Destination: Int] = [:]

    var body: some View {
        VStack(spacing: OrbitDesign.Spacing.card) {
            ForEach(orderedDestinations) { destination in
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) { selection = destination }
                } label: {
                    DestinationPhotoCard(
                        destination: destination,
                        durationMinutes: durationMinutes,
                        isSelected: selection == destination,
                        isRecommended: destination.isRecommended(for: durationMinutes),
                        isVisited: visitedDestinations.contains(destination),
                        completedCount: completedCounts[destination, default: 0]
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "destination.accessibility_label", defaultValue: "目的地、\(destination.name)"))
                .accessibilityValue(destination.isRecommended(for: durationMinutes) ? String(localized: "destination.accessibility_recommended", defaultValue: "現在の集中時間におすすめ") : destination.recommendationText)
                .accessibilityAddTraits(selection == destination ? .isSelected : [])
            }
        }
    }

    private var orderedDestinations: [Destination] {
        Destination.allCases.sorted { lhs, rhs in
            let leftRecommended = lhs.isRecommended(for: durationMinutes)
            let rightRecommended = rhs.isRecommended(for: durationMinutes)
            if leftRecommended != rightRecommended { return leftRecommended }
            return Destination.allCases.firstIndex(of: lhs)! < Destination.allCases.firstIndex(of: rhs)!
        }
    }
}

private struct DestinationPhotoCard: View {
    let destination: Destination
    let durationMinutes: Int
    let isSelected: Bool
    let isRecommended: Bool
    let isVisited: Bool
    let completedCount: Int

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color(red: 0.012, green: 0.02, blue: 0.04), destination.accent.opacity(0.08)],
                startPoint: .leading,
                endPoint: .trailing
            )
            HStack {
                Spacer()
                DestinationCardArtwork(destination: destination)
                    .frame(width: 258, height: 195)
            }
            .padding(.trailing, 2)
            LinearGradient(colors: [.black.opacity(0.88), .black.opacity(0.24), .clear], startPoint: .leading, endPoint: .trailing)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    Text(destination.name).font(.headline)
                    if isRecommended {
                        Text(String(localized: "common.recommended", defaultValue: "おすすめ"))
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(AppTheme.destination.opacity(0.18), in: Capsule())
                            .foregroundStyle(AppTheme.destination)
                    }
                }
                Text(destination.englishName)
                    .font(OrbitDesign.Typography.spaceLabel).tracking(1.4)
                    .foregroundStyle(.white.opacity(0.6))
                Text(destination.recommendationText)
                    .font(.caption2).foregroundStyle(AppTheme.secondary)
                HStack(spacing: 6) {
                    Image(systemName: isVisited ? "checkmark.seal.fill" : "circle.dashed")
                    Text(isVisited ? String(localized: "common.reached", defaultValue: "到達済み") : String(localized: "common.not_reached", defaultValue: "未到達"))
                    if !isRecommended && durationMinutes < destination.recommendedMinutes.lowerBound {
                        Text(String(localized: "destination.fast_mode", defaultValue: "・高速航行モード"))
                    }
                }
                .font(.caption2)
                .foregroundStyle(isVisited ? AppTheme.success : AppTheme.secondary)

                if completedCount > 0 {
                    let route = DestinationAchievement(destination: destination, completedCount: completedCount)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            Text(route.routeStatus)
                            Text(String(localized: "destination.completed_count", defaultValue: "・到達 \(completedCount)回"))
                        }
                        .font(.caption2.weight(.semibold))
                        ProgressView(value: route.rankProgress)
                            .tint(destination.accent)
                            .frame(maxWidth: 132)
                        Text(route.nextMilestoneText)
                            .font(.system(size: 9))
                            .foregroundStyle(AppTheme.secondary)
                    }
                }
            }
            .padding(15)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? destination.accent : .white.opacity(0.42))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(15)
        }
        .frame(height: 195)
        .clipShape(RoundedRectangle(cornerRadius: OrbitDesign.Radius.largeCard, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: OrbitDesign.Radius.largeCard).stroke(isSelected ? destination.accent : .white.opacity(0.12), lineWidth: isSelected ? 1.7 : 1))
        .shadow(color: isSelected ? destination.accent.opacity(0.16) : .clear, radius: 14)
        .opacity(isSelected ? 1 : 0.86)
    }

}

private struct DestinationCardArtwork: View {
    let destination: Destination

    var body: some View {
        CelestialBodyView(kind: .destination(destination))
            .frame(width: artworkSize, height: artworkSize)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(x: destination == .station ? 5 : 8)
            .clipped()
            .accessibilityHidden(true)
    }

    // The card uses the visible body diameter, not the source canvas size.
    // Saturn is intentionally enlarged until its globe matches the other planets;
    // the wide rings may extend beyond the artwork window.
    private var artworkSize: CGFloat {
        switch destination {
        case .moon: 216
        case .mercury: 283
        case .venus: 237
        case .mars: 205
        case .jupiter: 260
        case .saturn: 514
        case .uranus: 213
        case .neptune: 252
        case .pluto: 286
        case .station: 273
        }
    }
}

extension Destination {
    var recommendedMinutes: ClosedRange<Int> {
        switch self {
        case .moon: 5...25
        case .station: 5...30
        case .mercury: 15...40
        case .venus: 20...45
        case .mars: 20...45
        case .jupiter: 45...90
        case .saturn: 60...180
        case .uranus: 90...180
        case .neptune: 90...180
        case .pluto: 90...180
        }
    }

    var recommendationText: String {
        String(localized: "destination.recommendation", defaultValue: "推奨 \(recommendedMinutes.lowerBound)〜\(recommendedMinutes.upperBound)分")
    }

    func isRecommended(for duration: Int) -> Bool { recommendedMinutes.contains(duration) }
}
