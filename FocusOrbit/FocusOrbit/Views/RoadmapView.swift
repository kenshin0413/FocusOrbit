import SwiftUI

struct RoadmapView: View {
    let router: AppRouter
    let records: [RoadmapFocusRecord]
    let sessionManager: RoadmapSessionManager

    private var totalTrackedSeconds: TimeInterval {
        RoadmapStorageService.totalSeconds(records) + sessionManager.elapsedSeconds
    }

    private var progress: RoadmapProgress {
        RoadmapProgress(totalSeconds: totalTrackedSeconds)
    }

    private var needsInitialBoarding: Bool {
        totalTrackedSeconds <= 0 && sessionManager.needsInitialLaunch && sessionManager.pendingSurfaceDepartureIndex == nil
    }

    private var buttonTitle: String {
        if needsInitialBoarding { return String(localized: "roadmap.boarding", defaultValue: "搭乗認証へ進む") }
        if sessionManager.pendingSurfaceDepartureIndex != nil { return String(localized: "roadmap.scan_departure", defaultValue: "スキャンして離陸へ進む") }
        return String(localized: "roadmap.resume", defaultValue: "ロードマップ航行を再開")
    }

    private var buttonIcon: String {
        if needsInitialBoarding { return "person.text.rectangle" }
        if sessionManager.pendingSurfaceDepartureIndex != nil { return "point.3.connected.trianglepath.dotted" }
        return "arrow.right.circle.fill"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OrbitDesign.Spacing.section) {
                ScreenHeader(title: String(localized: "roadmap.title", defaultValue: "惑星ロードマップ"), subtitle: "PLANETARY ROADMAP") { router.returnHome() }
                currentFlight
                startButton
                route
                Text(String(localized: "roadmap.footer", defaultValue: "カスタム航行とは別に、すべての集中時間がこの航路へ加算されます。"))
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondary)
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: OrbitDesign.Size.contentMaxWidth)
            .padding(.horizontal, OrbitDesign.Spacing.screenHorizontal)
            .padding(.top, 8)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private var currentFlight: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    roadmapChip(progress.isComplete ? "COMPLETE" : "CURRENT LEG", tint: progress.target.accent)
                    Text(progress.isComplete ? String(localized: "roadmap.arrived", defaultValue: "航路到達") : String(localized: "roadmap.current_leg", defaultValue: "現在の航路"))
                        .font(.caption).foregroundStyle(AppTheme.secondary)
                    Text(progress.isComplete ? (RoadmapRoute.legs.last?.destination.name ?? progress.target.name) : "\(progress.originName) -> \(progress.target.name)")
                        .font(.title2.weight(.semibold))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(Formatters.hoursMinutes(totalTrackedSeconds))
                        .font(.headline.monospacedDigit())
                    Text(String(localized: "roadmap.total_focus_time", defaultValue: "累計集中時間"))
                        .font(.caption2)
                        .foregroundStyle(AppTheme.secondary)
                }
            }
            if !progress.isComplete {
                ProgressView(value: progress.legFraction)
                    .tint(progress.target.accent)
                HStack {
                    Text(LocalizedRuntime.text(ja: "区間進捗 \(Int(progress.legFraction * 100))%", en: "Leg Progress \(Int(progress.legFraction * 100))%"))
                    Spacer()
                    Text(LocalizedRuntime.text(ja: "残り \(Formatters.hoursMinutes(progress.remainingSeconds))", en: "Remaining \(Formatters.hoursMinutes(progress.remainingSeconds))"))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(AppTheme.secondary)
                HStack(spacing: 10) {
                    legPill(String(localized: "roadmap.arrival_effect", defaultValue: "到着で演出再生"), symbol: "sparkles")
                    legPill(progress.target.isSurfaceDestination ? String(localized: "roadmap.surface_transition", defaultValue: "着陸と離陸あり") : String(localized: "roadmap.flyby", defaultValue: "右回りフライバイ"), symbol: progress.target.isSurfaceDestination ? "airplane.departure" : "arrow.trianglehead.clockwise")
                }
            }
        }
        .spacePanel()
    }

    private var startButton: some View {
        Button {
            if needsInitialBoarding {
                if !sessionManager.isActive { sessionManager.beginPreflight() }
                router.show(sessionManager.isActive ? .roadmapFocus : .roadmapPass)
                return
            }
            if !sessionManager.isActive { sessionManager.startSession() }
            router.show(.roadmapFocus)
        } label: {
            Label(buttonTitle, systemImage: buttonIcon)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: OrbitDesign.Size.primaryButtonHeight)
                .background(AppTheme.navigation, in: RoundedRectangle(cornerRadius: OrbitDesign.Radius.button))
                .foregroundStyle(.black)
        }
        .buttonStyle(.plain)
        .accessibilityHint(String(localized: "roadmap.start.accessibility_hint", defaultValue: "終了時刻を決めずに集中を開始します"))
    }

    private var route: some View {
        VStack(spacing: 0) {
            earthRow
            ForEach(Array(RoadmapRoute.legs.enumerated()), id: \.element.id) { index, leg in
                connector(index: index, leg: leg)
                destinationRow(index: index, leg: leg)
            }
        }
        .padding(.vertical, 8)
    }

    private var earthRow: some View {
        HStack(spacing: 14) {
            CelestialBodyView(kind: .earth).frame(width: 62, height: 62)
            VStack(alignment: .leading, spacing: 3) {
                Text(String(localized: "common.earth", defaultValue: "地球")).font(.headline)
                Text(String(localized: "roadmap.departure_point", defaultValue: "出発地点")).font(.caption).foregroundStyle(AppTheme.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
    }

    private func connector(index: Int, leg: RoadmapLeg) -> some View {
        let active = index == progress.legIndex && !progress.isComplete
        let completed = index < progress.completedDestinationCount || progress.isComplete
        return HStack {
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(completed ? leg.destination.accent.opacity(0.8) : .white.opacity(0.16))
                    .frame(width: 2, height: 76)
                if active {
                    Rectangle()
                        .fill(leg.destination.accent)
                        .frame(width: 3, height: 76 * progress.legFraction)
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .offset(y: max(0, 70 * progress.legFraction - 8))
                        .shadow(color: leg.destination.accent, radius: 7)
                }
            }
            .frame(width: 62, height: 76)
            .padding(.leading, 12)
            Spacer()
            Text(index == 0 ? String(localized: "roadmap.moon_leg_duration", defaultValue: "50時間") : String(localized: "roadmap.standard_leg_duration", defaultValue: "100時間"))
                .font(.caption.monospacedDigit())
                .foregroundStyle(AppTheme.secondary)
                .padding(.trailing, 12)
        }
    }

    private func destinationRow(index: Int, leg: RoadmapLeg) -> some View {
        let reached = index < progress.completedDestinationCount || progress.isComplete
        let active = index == progress.legIndex && !progress.isComplete
        return HStack(spacing: 14) {
            CelestialBodyView(kind: .destination(leg.destination))
                .frame(width: 62, height: 62)
                .opacity(reached || active ? 1 : 0.42)
            VStack(alignment: .leading, spacing: 3) {
                Text(leg.destination.name).font(.headline)
                Text(reached ? String(localized: "common.reached", defaultValue: "到達済み") : active ? String(localized: "common.in_flight", defaultValue: "航行中") : String(localized: "common.not_reached", defaultValue: "未到達"))
                    .font(.caption)
                    .foregroundStyle(reached ? AppTheme.success : active ? leg.destination.accent : AppTheme.secondary)
            }
            Spacer()
            if reached { Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.success) }
        }
        .padding(12)
        .background(active ? leg.destination.accent.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(active ? leg.destination.accent.opacity(0.35) : .clear))
    }

    private func roadmapChip(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .tracking(1.1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14), in: Capsule())
            .foregroundStyle(tint)
    }

    private func legPill(_ title: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
            Text(title)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.05), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.08)))
        .foregroundStyle(AppTheme.secondary)
    }
}
