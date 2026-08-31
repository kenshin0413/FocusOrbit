import SwiftUI

struct CrewCardView: View {
    let router: AppRouter
    let profile: CrewProfile?
    let records: [MissionRecord]
    let roadmapRecords: [RoadmapFocusRecord]

    private var completedCount: Int { StorageService.completedCount(records) }
    private var totalSeconds: TimeInterval { StorageService.totalSeconds(records) }
    private var totalDistance: Double { records.reduce(0) { $0 + $1.distanceKilometers } }
    private var roadmapProgress: RoadmapProgress { RoadmapProgress(totalSeconds: RoadmapStorageService.totalSeconds(roadmapRecords)) }
    private var reachedRoadmapDestinations: Set<Destination> {
        Set(RoadmapRoute.legs.prefix(roadmapProgress.completedDestinationCount).map(\.destination))
    }
    private var topDestination: Destination? {
        Dictionary(grouping: records.filter(\.isFocusRecord), by: \.destination)
            .max { $0.value.count < $1.value.count }?.key
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                ScreenHeader(title: String(localized: "crew.title", defaultValue: "クルーカード"), subtitle: "CREW PROFILE") { router.returnHome() }
                identityDeck
                missionSummary
                roadmapStampDeck
                destinationHighlight
            }
            .padding(20)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
    }

    private var identityDeck: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.03, green: 0.07, blue: 0.16),
                            Color(red: 0.07, green: 0.05, blue: 0.14),
                            Color.black
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.06), .clear, .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FLIGHT CREW")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .tracking(1.6)
                            .foregroundStyle(AppTheme.blue)
                        Text(profile?.crewName ?? "KENSHIN")
                            .font(.system(size: 32, weight: .light, design: .rounded))
                        Text(String(localized: "crew.id", defaultValue: "CREW ID  \(profile?.crewID ?? "FO-0000")"))
                            .font(.caption)
                            .tracking(1.2)
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    Spacer()
                    ZStack {
                        Circle().fill(.white.opacity(0.05))
                        Circle().stroke(AppTheme.blue.opacity(0.18), lineWidth: 1)
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 32))
                            .foregroundStyle(AppTheme.blue)
                    }
                    .frame(width: 82, height: 82)
                }

                HStack(spacing: 12) {
                    statusBadge(String(localized: "crew.total_focus", defaultValue: "累計 \(Formatters.hoursMinutes(totalSeconds))"), symbol: "timer")
                    statusBadge("\(completedCount) MISSIONS", symbol: "checkmark.seal.fill")
                }

                VStack(alignment: .leading, spacing: 10) {
                    rowLabel(String(localized: "crew.total_distance", defaultValue: "総航行距離"), value: Formatters.distance(totalDistance))
                    rowLabel(String(localized: "crew.first_use_date", defaultValue: "初回利用日"), value: profile.map { $0.firstUseDate.formatted(date: .numeric, time: .omitted) } ?? "--")
                }
            }
            .padding(24)
        }
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(AppTheme.line))
        .shadow(color: .black.opacity(0.26), radius: 20, y: 12)
    }

    private var missionSummary: some View {
        HStack(spacing: 12) {
            metricTile(title: String(localized: "crew.completed_missions", defaultValue: "完了ミッション"), value: "\(completedCount)", detail: String(localized: "crew.completed_missions.detail", defaultValue: "集中完了回数"), tint: AppTheme.success)
            metricTile(title: String(localized: "crew.total_focus_time", defaultValue: "累計集中"), value: Formatters.hoursMinutes(totalSeconds), detail: String(localized: "crew.total_focus_time.detail", defaultValue: "記録済み集中時間"), tint: AppTheme.blue)
        }
    }

    @ViewBuilder
    private var roadmapStampDeck: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "crew.roadmap_stamps", defaultValue: "ロードマップ到達スタンプ"))
                        .font(.headline)
                    Text(String(localized: "crew.roadmap_stamps.detail", defaultValue: "到達した惑星をクルーカードへ刻みます"))
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondary)
                }
                Spacer()
                Text(String(localized: "crew.roadmap_progress", defaultValue: "\(reachedRoadmapDestinations.count)/\(RoadmapRoute.legs.count)"))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AppTheme.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(RoadmapRoute.legs) { leg in
                    roadmapStamp(for: leg.destination, reached: reachedRoadmapDestinations.contains(leg.destination))
                }
            }

            if !roadmapProgress.isComplete {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(roadmapProgress.target.accent)
                    Text(String(localized: "crew.next_destination", defaultValue: "次の到達: \(roadmapProgress.target.name)"))
                        .font(.caption.weight(.medium))
                    Spacer()
                    Text(String(localized: "crew.remaining", defaultValue: "残り \(Formatters.hoursMinutes(roadmapProgress.remainingSeconds))"))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(AppTheme.secondary)
                }
            }
        }
        .spacePanel()
    }

    @ViewBuilder
    private var destinationHighlight: some View {
        if let topDestination {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(topDestination.accent.opacity(0.14))
                    CelestialBodyView(kind: .destination(topDestination))
                        .frame(width: 74, height: 74)
                }
                .frame(width: 90, height: 90)

                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "crew.top_destination", defaultValue: "最も到達した目的地"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.secondary)
                    Text(topDestination.name)
                        .font(.title3.weight(.semibold))
                    Text(String(localized: "crew.top_destination_route", defaultValue: "\(topDestination.englishName) ROUTE"))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(topDestination.accent)
                }
                Spacer()
            }
            .spacePanel()
        }
    }

    private func rowLabel(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(AppTheme.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
        }
    }

    private func statusBadge(_ title: String, symbol: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
            Text(title)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.white.opacity(0.06), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.08)))
    }

    private func metricTile(title: String, value: String, detail: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail)
                .font(.caption)
                .foregroundStyle(AppTheme.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .padding(16)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(tint.opacity(0.18)))
    }

    private func roadmapStamp(for destination: Destination, reached: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(reached ? destination.accent.opacity(0.16) : .white.opacity(0.04))
                    .frame(width: 52, height: 52)
                CelestialBodyView(kind: .destination(destination))
                    .frame(width: 42, height: 42)
                    .opacity(reached ? 1 : 0.35)
                if reached {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "seal.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.success)
                                .background(Circle().fill(Color.black))
                                .offset(x: 5, y: -4)
                        }
                        Spacer()
                    }
                }
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(destination.name)
                    .font(.subheadline.weight(.semibold))
                Text(reached ? String(localized: "crew.stamp.acquired", defaultValue: "到達スタンプ取得") : String(localized: "crew.not_reached", defaultValue: "未到達"))
                    .font(.caption)
                    .foregroundStyle(reached ? AppTheme.success : AppTheme.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(reached ? destination.accent.opacity(0.08) : .white.opacity(0.025), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(reached ? destination.accent.opacity(0.24) : .white.opacity(0.06)))
    }
}
