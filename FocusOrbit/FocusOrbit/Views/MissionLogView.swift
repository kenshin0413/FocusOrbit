import SwiftData
import SwiftUI

private enum LogSection: String, CaseIterable, Identifiable {
    case overview
    case analysis
    case history
    case achievements
    var id: String { rawValue }
    var title: String {
        switch self {
        case .overview: LocalizedRuntime.text(ja: "概要", en: "Overview")
        case .analysis: LocalizedRuntime.text(ja: "分析", en: "Analysis")
        case .history: LocalizedRuntime.text(ja: "履歴", en: "History")
        case .achievements: LocalizedRuntime.text(ja: "実績", en: "Achievements")
        }
    }
}

struct MissionLogView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let router: AppRouter
    let interstitialAdManager: InterstitialAdManager
    let records: [MissionRecord]
    let roadmapRecords: [RoadmapFocusRecord]
    let settings: AppSettings?
    @State private var section: LogSection = .overview
    @State private var deletingRecordID: UUID?

    private var statistics: FocusStatisticsSnapshot { FocusStatisticsService.snapshot(records: records) }
    private var todaySecondsCombined: TimeInterval { statistics.todaySeconds + RoadmapStorageService.todaySeconds(roadmapRecords) }
    private var weekSecondsCombined: TimeInterval {
        statistics.weekSeconds + RoadmapStorageService.seconds(roadmapRecords, in: StorageService.currentWeek())
    }
    private var monthSecondsCombined: TimeInterval {
        statistics.monthSeconds + RoadmapStorageService.seconds(roadmapRecords, in: StorageService.currentMonth())
    }
    private var totalRoadmapSeconds: TimeInterval { RoadmapStorageService.totalSeconds(roadmapRecords) }
    private var totalCombinedSeconds: TimeInterval { statistics.totalSeconds + totalRoadmapSeconds }
    private var focusRecords: [MissionRecord] { records.filter(\.isFocusRecord).sorted { $0.completedAt > $1.completedAt } }
    private var sortedRecords: [MissionRecord] { records.sorted { $0.completedAt > $1.completedAt } }
    private var metricColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OrbitDesign.Spacing.section) {
                ScreenHeader(title: LocalizedRuntime.text(ja: "集中記録", en: "Focus Log"), subtitle: "FOCUS ARCHIVE") { router.returnHome() }
                summaryHero
                primaryMetrics
                weeklyGoal
                sectionPicker

                switch section {
                case .overview: overview
                case .analysis: analysis
                case .history: history
                case .achievements: achievements
                }
            }
            .frame(maxWidth: OrbitDesign.Size.contentMaxWidth)
            .padding(.horizontal, OrbitDesign.Spacing.screenHorizontal)
            .padding(.vertical, 14)
            .padding(.bottom, 110)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .confirmationDialog(LocalizedRuntime.text(ja: "この集中記録を削除しますか？", en: "Delete this focus record?"), isPresented: deleteDialogBinding, titleVisibility: .visible) {
            Button(LocalizedRuntime.text(ja: "記録を削除", en: "Delete Record"), role: .destructive, action: deleteSelectedRecord)
            Button(LocalizedRuntime.text(ja: "キャンセル", en: "Cancel"), role: .cancel) { deletingRecordID = nil }
        } message: {
            Text(LocalizedRuntime.text(ja: "統計からも除外されます。この操作は取り消せません。", en: "It will also be removed from your stats. This cannot be undone."))
        }
    }

    private var summaryHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ALL FLIGHT TIME")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(AppTheme.blue)
                    Text(Formatters.hoursMinutes(totalCombinedSeconds))
                        .font(.system(size: 34, weight: .light, design: .rounded))
                        .monospacedDigit()
                    Text(LocalizedRuntime.text(ja: "カスタム航行とロードマップをまとめて表示", en: "Combined total for custom flights and roadmap"))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    modeBadge(LocalizedRuntime.text(ja: "カスタム航行", en: "Custom Flight"), value: Formatters.hoursMinutes(statistics.totalSeconds), tint: AppTheme.navigation)
                    modeBadge(LocalizedRuntime.text(ja: "ロードマップ", en: "Roadmap"), value: Formatters.hoursMinutes(totalRoadmapSeconds), tint: AppTheme.destination)
                }
            }
            HStack(spacing: 10) {
                insightPill(LocalizedRuntime.text(ja: "完了率", en: "Completion") + " \(statistics.sessionCount == 0 ? "--" : statistics.completionRate.formatted(.percent.precision(.fractionLength(0))))", symbol: "checkmark.seal.fill")
                insightPill(LocalizedRuntime.text(ja: "連続", en: "Streak") + " " + LocalizedRuntime.text(ja: "\(statistics.currentStreak)日", en: "\(statistics.currentStreak) days"), symbol: "flame.fill")
            }
        }
        .spacePanel()
    }

    private var primaryMetrics: some View {
        LazyVGrid(columns: metricColumns, spacing: OrbitDesign.Spacing.card) {
            MetricCard(label: LocalizedRuntime.text(ja: "今日の集中時間", en: "Today's Focus"), value: Formatters.hoursMinutes(todaySecondsCombined), symbol: "sun.max")
            MetricCard(label: LocalizedRuntime.text(ja: "今週の集中時間", en: "This Week"), value: Formatters.hoursMinutes(weekSecondsCombined), symbol: "calendar")
            MetricCard(label: LocalizedRuntime.text(ja: "今月の集中時間", en: "This Month"), value: Formatters.hoursMinutes(monthSecondsCombined), symbol: "calendar.badge.clock")
            MetricCard(label: LocalizedRuntime.text(ja: "達成率", en: "Completion"), value: statistics.sessionCount == 0 ? "--" : statistics.completionRate.formatted(.percent.precision(.fractionLength(0))), symbol: "checkmark.seal")
        }
    }

    @ViewBuilder private var weeklyGoal: some View {
        if settings?.weeklyGoalEnabled ?? true {
            let goal = max(settings?.weeklyFocusGoalMinutes ?? 150, 1)
            let currentMinutes = Int(weekSecondsCombined / 60)
            let progress = min(max(weekSecondsCombined / TimeInterval(goal * 60), 0), 1)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(LocalizedRuntime.text(ja: "週間目標", en: "Weekly Goal"), systemImage: "scope").font(.headline)
                    Spacer()
                    Text(String(localized: "logs.weekly_goal.progress", defaultValue: "\(currentMinutes) / \(goal)分")).font(.subheadline.monospacedDigit())
                }
                ProgressView(value: progress).tint(AppTheme.navigation)
                Text(progress >= 1
                     ? LocalizedRuntime.text(ja: "今週の目標に到達しました", en: "You reached this week's goal")
                     : LocalizedRuntime.text(ja: "あと\(max(goal - currentMinutes, 0))分で今週の目標です", en: "\(max(goal - currentMinutes, 0)) min to this week's goal"))
                    .font(.caption).foregroundStyle(AppTheme.secondary)
            }
            .spacePanel()
            .accessibilityElement(children: .combine)
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: OrbitDesign.Spacing.section) {
            chartCard(LocalizedRuntime.text(ja: "直近7日間", en: "Last 7 Days"), subtitle: "DAILY FOCUS") {
                if focusRecords.isEmpty { emptyChart }
                else { DailyFocusChart(points: FocusStatisticsService.dailyPoints(records: records)) }
            }
        }
    }

    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(LogSection.allCases) { item in
                    Button {
                        guard section != item else { return }
                        interstitialAdManager.handleTrigger {
                            section = item
                        }
                    } label: {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(section == item ? AppTheme.blue.opacity(0.18) : .white.opacity(0.05), in: Capsule())
                            .overlay(Capsule().stroke(section == item ? AppTheme.blue : .white.opacity(0.08), lineWidth: 1))
                            .foregroundStyle(section == item ? AppTheme.blue : AppTheme.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityLabel(LocalizedRuntime.text(ja: "記録画面の表示切り替え", en: "Switch log sections"))
    }

    private var analysis: some View {
        VStack(alignment: .leading, spacing: OrbitDesign.Spacing.section) {
            chartCard(LocalizedRuntime.text(ja: "曜日別集中時間", en: "Focus by Weekday"), subtitle: "WEEKDAY") {
                if focusRecords.isEmpty { emptyChart }
                else { FocusCategoryChart(title: LocalizedRuntime.text(ja: "曜日別集中時間", en: "Focus by Weekday"), points: FocusStatisticsService.weekdayPoints(records: records), unit: LocalizedRuntime.text(ja: "分", en: " min")) }
            }
            chartCard(LocalizedRuntime.text(ja: "時間帯別の集中回数", en: "Sessions by Time of Day"), subtitle: "TIME OF DAY") {
                if focusRecords.isEmpty { emptyChart }
                else { FocusCategoryChart(title: LocalizedRuntime.text(ja: "時間帯別の集中回数", en: "Sessions by Time of Day"), points: FocusStatisticsService.timeBandPoints(records: records), unit: LocalizedRuntime.text(ja: "回", en: " runs"), color: AppTheme.destination) }
            }
            chartCard(LocalizedRuntime.text(ja: "集中評価", en: "Focus Rating"), subtitle: "FOCUS QUALITY") {
                let ratings = FocusStatisticsService.ratingDistribution(records: records)
                if ratings.allSatisfy({ $0.count == 0 }) { emptyChart }
                else { RatingDistributionChart(items: ratings) }
            }
            chartCard(LocalizedRuntime.text(ja: "目的地別の利用回数", en: "Usage by Destination"), subtitle: "DESTINATIONS") {
                if focusRecords.isEmpty { emptyChart }
                else { FocusCategoryChart(title: LocalizedRuntime.text(ja: "目的地別の利用回数", en: "Usage by Destination"), points: FocusStatisticsService.destinationPoints(records: records), unit: LocalizedRuntime.text(ja: "回", en: " runs"), color: AppTheme.destination) }
            }
        }
    }

    private var history: some View {
        LazyVStack(alignment: .leading, spacing: OrbitDesign.Spacing.card) {
            if sortedRecords.isEmpty {
                ContentUnavailableView(LocalizedRuntime.text(ja: "集中記録はありません", en: "No focus records yet"), systemImage: "timer", description: Text(LocalizedRuntime.text(ja: "完了または中断した集中がここに保存されます", en: "Completed or interrupted sessions will appear here")))
            } else {
                ForEach(sortedRecords) { record in
                    if record.isFocusRecord {
                        Button { router.show(.missionDetail(record.id)) } label: { HistoryRecordRow(record: record) }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(LocalizedRuntime.text(ja: "同じ設定で再開始", en: "Start Again"), systemImage: "arrow.clockwise") { repeatMission(record) }
                                Button(LocalizedRuntime.text(ja: "削除", en: "Delete"), systemImage: "trash", role: .destructive) { deletingRecordID = record.id }
                            }
                    } else {
                        BreakHistoryRow(record: record)
                            .contextMenu {
                                Button(LocalizedRuntime.text(ja: "削除", en: "Delete"), systemImage: "trash", role: .destructive) { deletingRecordID = record.id }
                            }
                    }
                }
            }
        }
    }

    private var achievements: some View {
        VStack(alignment: .leading, spacing: OrbitDesign.Spacing.card) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(LocalizedRuntime.text(ja: "到達記録", en: "Arrival Record")).font(.headline)
                    Text(LocalizedRuntime.text(ja: "集中完了時に自動更新", en: "Updates automatically when a focus session completes")).font(.caption).foregroundStyle(AppTheme.secondary)
                }
                Spacer()
                    Text(String(localized: "logs.achievements.progress", defaultValue: "\(FocusStatisticsService.achievements(records: records).filter(\.isReached).count) / \(Destination.allCases.count)"))
                    .font(.headline.monospacedDigit())
            }
            ForEach(FocusStatisticsService.achievements(records: records)) { achievement in
                HStack(spacing: 14) {
                    CelestialBodyView(kind: .destination(achievement.destination)).frame(width: 58, height: 58).saturation(achievement.isReached ? 1 : 0)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(achievement.destination.name).font(.headline)
                        Text(achievement.isReached ? LocalizedRuntime.text(ja: "到達 \(achievement.completedCount)回", en: "\(achievement.completedCount) arrivals") : LocalizedRuntime.text(ja: "未到達", en: "Not reached"))
                            .font(.caption).foregroundStyle(AppTheme.secondary)
                        if achievement.isReached {
                            ProgressView(value: achievement.rankProgress)
                                .tint(achievement.destination.accent)
                            Text(achievement.nextMilestoneText)
                                .font(.caption2).foregroundStyle(AppTheme.secondary)
                        }
                    }
                    Spacer()
                    if let badge = achievement.badgeTitle {
                        Label(badge, systemImage: "seal.fill").font(.caption.weight(.semibold)).foregroundStyle(AppTheme.success)
                    } else {
                        Image(systemName: "lock.fill").foregroundStyle(AppTheme.secondary)
                    }
                }
                .spacePanel()
                .accessibilityElement(children: .combine)
            }
            compactMetric(LocalizedRuntime.text(ja: "累計航行距離", en: "Total Flight Distance"), Formatters.distance(records.filter { $0.isFocusRecord }.reduce(0) { $0 + $1.distanceKilometers }), "point.topleft.down.to.point.bottomright.curvepath")
        }
    }

    private func chartCard<Content: View>(_ title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Text(subtitle).font(OrbitDesign.Typography.spaceLabel).foregroundStyle(AppTheme.secondary)
            }
            content()
        }.spacePanel()
    }

    private var emptyChart: some View {
        ContentUnavailableView(String(localized: "logs.no_analysis", defaultValue: "分析データがありません"), systemImage: "chart.bar", description: Text(String(localized: "logs.no_analysis.detail", defaultValue: "集中記録が増えるとグラフを表示します")))
            .frame(maxWidth: .infinity, minHeight: 150)
    }

    private func compactMetric(_ label: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(label, systemImage: symbol).font(.caption).foregroundStyle(AppTheme.secondary)
            Text(value).font(.headline.monospacedDigit()).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .spacePanel()
        .accessibilityElement(children: .combine)
    }

    private func pomodoroMetric(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) { Text(value).font(.headline.monospacedDigit()); Text(label).font(.caption2).foregroundStyle(AppTheme.secondary) }
            .frame(maxWidth: .infinity)
    }

    private var deleteDialogBinding: Binding<Bool> {
        Binding(get: { deletingRecordID != nil }, set: { if !$0 { deletingRecordID = nil } })
    }

    private func deleteSelectedRecord() {
        guard let id = deletingRecordID, let record = records.first(where: { $0.id == id }) else { return }
        context.delete(record)
        try? context.save()
        deletingRecordID = nil
    }

    private func repeatMission(_ record: MissionRecord) {
        router.repeatMission(focusTitle: record.focusTitle, durationMinutes: record.plannedMinutes, destination: record.destination)
    }

    private func modeBadge(_ title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(tint)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(tint.opacity(0.22)))
    }

    private func insightPill(_ title: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
            Text(title)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.white.opacity(0.05), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.08)))
        .foregroundStyle(AppTheme.secondary)
    }
}

private struct BreakHistoryRow: View {
    let record: MissionRecord
    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.title3).foregroundStyle(AppTheme.transit)
                .frame(width: 48, height: 48)
                .background(AppTheme.transit.opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "common.break", defaultValue: "休憩")).font(.subheadline.weight(.semibold))
                Text(String(localized: "logs.break.after_cycle", defaultValue: "\(Formatters.hoursMinutes(record.actualSeconds))・第\(record.pomodoroCycle)サイクル後"))
                    .font(.caption).foregroundStyle(AppTheme.secondary)
                Text(record.wasAutomaticallyStarted ? String(localized: "common.auto_started", defaultValue: "自動開始") : String(localized: "common.manual_started", defaultValue: "手動開始"))
                    .font(.caption2).foregroundStyle(AppTheme.secondary)
            }
            Spacer()
            Text(record.completedAt.formatted(date: .numeric, time: .shortened))
                .font(.caption2).foregroundStyle(AppTheme.secondary)
        }
        .spacePanel()
        .accessibilityElement(children: .combine)
    }
}

private struct HistoryRecordRow: View {
    let record: MissionRecord
    var body: some View {
        HStack(spacing: 13) {
            CelestialBodyView(kind: .destination(record.destination)).frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(record.focusTitle).font(.subheadline.weight(.semibold)).lineLimit(1)
                    if record.isPomodoro { Text(String(localized: "pomodoro.badge", defaultValue: "POMODORO")).font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(AppTheme.destination) }
                }
                Text(String(localized: "logs.record.summary", defaultValue: "\(record.destination.name)・予定\(record.plannedMinutes)分・実績\(Formatters.hoursMinutes(record.actualSeconds))"))
                    .font(.caption).foregroundStyle(AppTheme.secondary).lineLimit(1)
                Text(String(localized: "logs.record.details", defaultValue: "一時停止 \(record.pauseCount)回・\(record.displayMode.japaneseTitle)・\(record.rating?.title ?? "未評価")"))
                    .font(.caption2).foregroundStyle(AppTheme.secondary).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Label(record.isCompleted ? String(localized: "common.completed", defaultValue: "完了") : String(localized: "common.interrupted", defaultValue: "中断"), systemImage: record.isCompleted ? "checkmark.circle.fill" : "stop.circle.fill")
                    .font(.caption2).foregroundStyle(record.isCompleted ? AppTheme.success : AppTheme.warning)
                Text(record.completedAt.formatted(date: .numeric, time: .shortened)).font(.caption2).foregroundStyle(AppTheme.secondary)
            }
        }
        .spacePanel()
        .accessibilityElement(children: .combine)
        .accessibilityHint(String(localized: "logs.record.accessibility_hint", defaultValue: "詳細を開きます。長押しで再開始または削除できます"))
    }
}
