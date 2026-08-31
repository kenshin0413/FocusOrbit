import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let router: AppRouter
    let interstitialAdManager: InterstitialAdManager
    let records: [MissionRecord]
    let roadmapRecords: [RoadmapFocusRecord]
    let profile: CrewProfile?
    let settings: AppSettings?
    @State private var ambientMotion = false

    private var latest: MissionRecord? { records.max { $0.completedAt < $1.completedAt } }
    private var streak: Int { StorageService.streak(records) }
    private var roadmapProgress: RoadmapProgress { RoadmapProgress(totalSeconds: RoadmapStorageService.totalSeconds(roadmapRecords)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OrbitDesign.Spacing.section) {
                header
                todaySummary
                roadmapCard
                standardFocusCard
            }
            .frame(maxWidth: OrbitDesign.Size.contentMaxWidth)
            .padding(.horizontal, OrbitDesign.Spacing.screenHorizontal)
            .padding(.top, 10)
            .padding(.bottom, 120)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) { ambientMotion = true }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("FOCUS ORBIT")
                    .font(.system(size: 28, weight: .light, design: .rounded))
                    .tracking(2)
                Text(String(localized: "home.subtitle", defaultValue: "宇宙集中タイマー"))
                    .font(OrbitDesign.Typography.spaceLabel)
                    .tracking(1.5)
                    .foregroundStyle(AppTheme.secondary)
            }
            Spacer()
            Button { router.show(.crew) } label: {
                ZStack {
                    Circle().fill(AppTheme.blue.opacity(0.13))
                    Image(systemName: "person.fill").foregroundStyle(AppTheme.blue)
                }
                .frame(width: OrbitDesign.Size.minimumTap, height: OrbitDesign.Size.minimumTap)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "home.open_crew_card", defaultValue: "クルーカードを開く"))
        }
    }

    private var todaySummary: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let todaySeconds = StorageService.todaySeconds(records, now: timeline.date)
                + RoadmapStorageService.todaySeconds(roadmapRecords, now: timeline.date)

            RoundedRectangle(cornerRadius: OrbitDesign.Radius.largeCard, style: .continuous)
                .fill(LinearGradient(
                        colors: [Color(red: 0.05, green: 0.10, blue: 0.18), Color(red: 0.02, green: 0.032, blue: 0.07)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                ))
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .stroke(AppTheme.blue.opacity(0.12), lineWidth: 1)
                        .frame(width: 228, height: 228)
                        .offset(x: 76, y: 126)
                }
                .overlay(alignment: .bottomTrailing) {
                    CelestialBodyView(kind: .earth)
                        .frame(width: 236, height: 236)
                        .offset(x: 90, y: 122)
                        .opacity(0.22)
                        .scaleEffect(ambientMotion ? 1.045 : 1)
                }
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 4) {
                        statusChip("MISSION CONTROL", color: AppTheme.blue)
                        Text(String(localized: "home.today_focus_time", defaultValue: "今日の集中時間")).font(.headline)
                        Text("TODAY'S FLIGHT TIME")
                            .font(OrbitDesign.Typography.spaceLabel).tracking(1.2)
                            .foregroundStyle(AppTheme.secondary)
                        Text(Formatters.hoursMinutes(todaySeconds))
                            .font(.system(size: 36, weight: .light, design: .rounded))
                            .monospacedDigit()
                        Label(streak == 0 ? String(localized: "home.streak.start_today", defaultValue: "今日から航行を始めましょう") : String(localized: "home.streak.days", defaultValue: "\(streak)日連続航行中"), systemImage: streak == 0 ? "sparkles" : "flame.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(streak == 0 ? AppTheme.secondary : AppTheme.success)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                    .padding(.bottom, 18)
                }
        }
        .frame(height: 198)
        .clipShape(RoundedRectangle(cornerRadius: OrbitDesign.Radius.largeCard, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: OrbitDesign.Radius.largeCard).stroke(AppTheme.line))
        .accessibilityElement(children: .combine)
    }

    private var standardFocusCard: some View {
        Button {
            interstitialAdManager.handleTrigger {
                router.startNewMission()
            }
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        statusChip("CUSTOM", color: AppTheme.navigation)
                        Text(String(localized: "home.custom_focus.title", defaultValue: "カスタム航行")).font(.title3.weight(.semibold))
                        Text(String(localized: "home.custom_focus.detail", defaultValue: "内容・時間・目的地を決めて、そのまま集中に入る"))
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondary)
                    }
                    Spacer()
                    ZStack {
                        Circle().fill(AppTheme.blue.opacity(0.12))
                        CelestialBodyView(kind: .earth)
                            .frame(width: 46, height: 46)
                    }
                    .frame(width: 58, height: 58)
                }
                HStack(spacing: 10) {
                    cardPill(String(localized: "home.custom_focus.free_config", defaultValue: "自由設定"), symbol: "slider.horizontal.3")
                    cardPill(String(localized: "home.custom_focus.launch_from_earth", defaultValue: "地球から出発"), symbol: "globe.americas.fill")
                    if let latest {
                        cardPill(LocalizedRuntime.text(ja: "前回\(latest.plannedMinutes)分", en: "Last \(latest.plannedMinutes) min"), symbol: "clock.arrow.circlepath")
                    }
                }
                HStack {
                    Text(String(localized: "home.custom_focus.cta", defaultValue: "カスタム航行を設定"))
                        .font(.headline)
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.blue)
                }
            }
            .spacePanel()
        }
        .buttonStyle(PrimaryPressStyle())
        .accessibilityLabel(String(localized: "home.custom_focus.accessibility_label", defaultValue: "カスタム航行"))
        .accessibilityHint(String(localized: "home.custom_focus.accessibility_hint", defaultValue: "集中内容、時間、目的地を設定します"))
    }

    private var roadmapCard: some View {
        return Button {
            interstitialAdManager.handleTrigger {
                router.show(.roadmap)
            }
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            statusChip("ROADMAP", color: roadmapProgress.target.accent)
                            Text(String(localized: "common.recommended", defaultValue: "おすすめ"))
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(roadmapProgress.target.accent.opacity(0.18), in: Capsule())
                                .foregroundStyle(roadmapProgress.target.accent)
                        }
                        Text(String(localized: "home.roadmap.title", defaultValue: "惑星ロードマップ")).font(.title3.weight(.semibold))
                        Text(roadmapProgress.isComplete
                             ? String(localized: "home.roadmap.complete", defaultValue: "太陽系ロードマップを完了しています")
                             : LocalizedRuntime.text(
                                ja: "\(roadmapProgress.originName)から\(roadmapProgress.target.name)へ、積み上げた時間でそのまま進む",
                                en: "From \(roadmapProgress.originName) to \(roadmapProgress.target.name), advancing with your accumulated time"
                             ))
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondary)
                    }
                    Spacer()
                    ZStack {
                        Circle().fill(roadmapProgress.target.accent.opacity(0.12))
                        CelestialBodyView(kind: .destination(roadmapProgress.target))
                            .frame(width: 46, height: 46)
                    }
                    .frame(width: 58, height: 58)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(roadmapProgress.originName) -> \(roadmapProgress.target.name)")
                            .font(.headline.monospaced())
                        Spacer()
                        Text(LocalizedRuntime.text(ja: "残り\(Formatters.hoursMinutes(roadmapProgress.remainingSeconds))", en: "Remaining \(Formatters.hoursMinutes(roadmapProgress.remainingSeconds))"))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(roadmapProgress.target.accent)
                    }
                    ProgressView(value: progressValue)
                        .tint(roadmapProgress.target.accent)
                    HStack(spacing: 10) {
                        cardPill(String(localized: "home.roadmap.carry_over", defaultValue: "継続記録を反映"), symbol: "point.3.connected.trianglepath.dotted")
                        cardPill(String(localized: "home.roadmap.landing_departure", defaultValue: "着陸と離陸あり"), symbol: "airplane.departure")
                    }
                    HStack {
                        Text(roadmapProgress.isComplete ? String(localized: "home.roadmap.cta_complete", defaultValue: "ロードマップを確認") : String(localized: "home.roadmap.cta_continue", defaultValue: "ロードマップを続行"))
                            .font(.headline)
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title3)
                            .foregroundStyle(AppTheme.blue)
                    }
                }
            }
            .spacePanel()
        }
        .buttonStyle(PrimaryPressStyle())
        .accessibilityLabel(String(localized: "home.roadmap.accessibility_label", defaultValue: "惑星ロードマップ"))
        .accessibilityValue(LocalizedRuntime.text(ja: "\(roadmapProgress.target.name)まで残り\(Formatters.hoursMinutes(roadmapProgress.remainingSeconds))", en: "\(Formatters.hoursMinutes(roadmapProgress.remainingSeconds)) remaining to \(roadmapProgress.target.name)"))
    }

    private var progressValue: Double {
        let total = roadmapProgress.totalSeconds
        let remaining = roadmapProgress.remainingSeconds
        guard total + remaining > 0 else { return 0 }
        return min(max(total / (total + remaining), 0), 1)
    }

    private func statusChip(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .tracking(1.1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.14), in: Capsule())
            .foregroundStyle(color)
    }

    private func cardPill(_ title: String, symbol: String) -> some View {
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

private struct PrimaryPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct RecordRow: View {
    let record: MissionRecord
    var body: some View {
        HStack(spacing: 13) {
            CelestialBodyView(kind: .destination(record.destination)).frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(record.destination.name).font(.subheadline.weight(.semibold))
                Text(record.focusTitle).font(.caption).foregroundStyle(AppTheme.secondary).lineLimit(1)
                Text(Formatters.dateTime.string(from: record.completedAt)).font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Text(Formatters.hoursMinutes(record.actualSeconds)).font(.caption).monospacedDigit()
                Text(record.isCompleted ? LocalizedRuntime.text(ja: "完了", en: "Completed") : LocalizedRuntime.text(ja: "中断", en: "Interrupted")).font(.caption2).foregroundStyle(record.isCompleted ? AppTheme.success : .orange)
            }
        }
        .spacePanel()
    }
}
