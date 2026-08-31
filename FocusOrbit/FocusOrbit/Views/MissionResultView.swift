import SwiftData
import SwiftUI

struct MissionResultView: View {
    @Environment(\.modelContext) private var context
    let router: AppRouter
    let mission: Mission
    let record: MissionRecord
    let crewName: String
    let sessionManager: FocusSessionManager
    let allRecords: [MissionRecord]
    let settings: AppSettings?
    @State private var stamped = false
    @State private var showSummary = false
    @State private var showingBreakOptions = false
    @State private var showingCustomBreak = false
    @State private var customBreakMinutes = 5

    var body: some View {
        ScrollView {
            VStack(spacing: OrbitDesign.Spacing.section) {
                completionHeader
                if showSummary {
                    achievementCard.transition(.move(edge: .bottom).combined(with: .opacity))
                    actionButtons.transition(.move(edge: .bottom).combined(with: .opacity))
                    observationCard
                    missionDetails
                }
            }
            .frame(maxWidth: OrbitDesign.Size.contentMaxWidth)
            .padding(.horizontal, OrbitDesign.Spacing.screenHorizontal)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .confirmationDialog(String(localized: "result.break_picker", defaultValue: "休憩時間を選択"), isPresented: $showingBreakOptions, titleVisibility: .visible) {
            Button(String(localized: "result.break_five", defaultValue: "5分")) { startBreak(minutes: 5) }
            Button(String(localized: "result.break_ten", defaultValue: "10分")) { startBreak(minutes: 10) }
            Button(String(localized: "common.custom", defaultValue: "カスタム")) { showingCustomBreak = true }
            Button(String(localized: "common.cancel", defaultValue: "キャンセル"), role: .cancel) {}
        }
        .sheet(isPresented: $showingCustomBreak) { customBreakPicker }
        .onAppear {
            withAnimation(.spring(duration: 0.7).delay(0.15)) { stamped = true }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.86).delay(0.35)) { showSummary = true }
            if mission.automaticallyStartBreak {
                Task {
                    try? await Task.sleep(for: .seconds(2.5))
                    guard router.screen == .result, sessionManager.status == .completed else { return }
                    sessionManager.startBreak()
                    router.show(.breakSession, missionID: mission.id)
                }
            }
        }
    }

    private var completionHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(AppTheme.success.opacity(0.12)).frame(width: 68, height: 68)
                Image(systemName: record.isCompleted ? "checkmark.seal.fill" : "stop.circle.fill")
                    .font(.system(size: 34)).foregroundStyle(record.isCompleted ? AppTheme.success : .orange)
            }
            Text(record.isCompleted ? String(localized: "result.complete", defaultValue: "ミッション完了") : String(localized: "result.interrupted", defaultValue: "ミッションを終了しました"))
                .font(.title2.weight(.semibold))
            Text(record.isCompleted ? String(localized: "result.complete_english", defaultValue: "MISSION COMPLETE") : String(localized: "result.interrupted_english", defaultValue: "MISSION INTERRUPTED"))
                .font(OrbitDesign.Typography.spaceLabel).tracking(1.8)
                .foregroundStyle(record.isCompleted ? AppTheme.success : .orange)
            Text(record.focusTitle)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var achievementCard: some View {
        VStack(spacing: 18) {
            VStack(spacing: 5) {
                Text(
                    record.isCompleted
                    ? LocalizedRuntime.text(ja: "\(achievedMinutes)分間の集中を達成しました", en: "You completed \(achievedMinutes) minutes of focus")
                    : LocalizedRuntime.text(ja: "\(achievedMinutes)分間の集中を記録しました", en: "You recorded \(achievedMinutes) minutes of focus")
                )
                    .font(.title2.weight(.semibold)).multilineTextAlignment(.center)
                Text(String(localized: "result.saved_record", defaultValue: "\(record.destination.name)へ向かった記録として保存されます"))
                    .font(.subheadline).foregroundStyle(AppTheme.secondary).lineLimit(2)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) {
                    achievementMetric(String(localized: "common.destination", defaultValue: "目的地"), record.destination.name, "scope")
                    divider
                    achievementMetric(String(localized: "result.focus_time", defaultValue: "集中時間"), Formatters.hoursMinutes(record.actualSeconds), "timer")
                    divider
                    achievementMetric(String(localized: "result.pause_count", defaultValue: "一時停止"), String(localized: "result.pause_count_value", defaultValue: "\(record.pauseCount)回"), "pause.circle")
                }
                VStack(spacing: 10) {
                    achievementMetric(String(localized: "common.destination", defaultValue: "目的地"), record.destination.name, "scope")
                    achievementMetric(String(localized: "result.focus_time", defaultValue: "集中時間"), Formatters.hoursMinutes(record.actualSeconds), "timer")
                    achievementMetric(String(localized: "result.pause_count", defaultValue: "一時停止"), String(localized: "result.pause_count_value", defaultValue: "\(record.pauseCount)回"), "pause.circle")
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    summaryPill(String(localized: "result.today_total", defaultValue: "今日の合計"), Formatters.hoursMinutes(StorageService.todaySeconds(allRecords)), "calendar")
                    summaryPill(String(localized: "result.streak", defaultValue: "連続達成"), String(localized: "result.streak_value", defaultValue: "\(StorageService.streak(allRecords))日"), "flame")
                }
                VStack(spacing: 10) {
                    summaryPill(String(localized: "result.today_total", defaultValue: "今日の合計"), Formatters.hoursMinutes(StorageService.todaySeconds(allRecords)), "calendar")
                    summaryPill(String(localized: "result.streak", defaultValue: "連続達成"), String(localized: "result.streak_value", defaultValue: "\(StorageService.streak(allRecords))日"), "flame")
                }
            }
        }
        .padding(20)
        .background(LinearGradient(colors: [AppTheme.panel, AppTheme.success.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: OrbitDesign.Radius.largeCard))
        .overlay(RoundedRectangle(cornerRadius: OrbitDesign.Radius.largeCard).stroke(AppTheme.success.opacity(0.36)))
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button { showingBreakOptions = true } label: {
                Label(String(localized: "result.start_break", defaultValue: "休憩を開始"), systemImage: "cup.and.saucer.fill")
                    .frame(maxWidth: .infinity, minHeight: OrbitDesign.Size.primaryButtonHeight)
                    .background(AppTheme.navigation, in: RoundedRectangle(cornerRadius: OrbitDesign.Radius.button))
                    .foregroundStyle(.black).fontWeight(.bold)
            }
            Button { repeatMission() } label: {
                Label(String(localized: "result.repeat", defaultValue: "同じ設定でもう一度"), systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity, minHeight: OrbitDesign.Size.primaryButtonHeight)
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: OrbitDesign.Radius.button))
                    .overlay(RoundedRectangle(cornerRadius: OrbitDesign.Radius.button).stroke(.white.opacity(0.10)))
            }
            Button(String(localized: "common.return_home", defaultValue: "ホームへ戻る")) {
                sessionManager.clearFinishedSession(); router.returnHome()
            }
            .frame(minHeight: OrbitDesign.Size.minimumTap)
            .foregroundStyle(AppTheme.secondary)
        }
        .buttonStyle(.plain)
    }

    private var observationCard: some View {
        let route = DestinationAchievement(
            destination: record.destination,
            completedCount: allRecords.filter { $0.isFocusRecord && $0.isCompleted && $0.destination == record.destination }.count
        )
        return HStack(spacing: 13) {
            CelestialBodyView(kind: .destination(record.destination)).frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(record.isCompleted ? String(localized: "result.route_status", defaultValue: "\(record.destination.name)航路・\(route.routeStatus)") : String(localized: "result.partial_recorded", defaultValue: "途中航行を記録しました"))
                    .font(.subheadline.weight(.semibold))
                Text(record.isCompleted ? route.nextMilestoneText : String(localized: "result.partial_recorded.detail", defaultValue: "集中時間と到達距離を航行ログへ保存"))
                    .font(.caption).foregroundStyle(AppTheme.secondary)
                if record.isCompleted {
                    ProgressView(value: route.rankProgress)
                        .tint(record.destination.accent)
                }
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.success)
        }
        .spacePanel()
    }

    private var missionDetails: some View {
        DisclosureGroup {
            VStack(spacing: 14) {
                MissionPassCard(mission: mission, crewName: crewName, completed: stamped && record.isCompleted)
                resultRow(String(localized: "result.distance", defaultValue: "航行距離"), Formatters.distance(record.distanceKilometers))
                resultRow(String(localized: "result.completed_at", defaultValue: "完了日時"), Formatters.dateTime.string(from: record.completedAt))
                resultRow(String(localized: "result.mission_number", defaultValue: "ミッション番号"), record.missionNumber)
            }.padding(.top, 12)
        } label: {
            HStack {
                Text(String(localized: "result.details_title", defaultValue: "航行データとミッションパス"))
                Spacer()
                Text("DETAILS")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.secondary)
            }
        }
        .spacePanel()
    }

    private var customBreakPicker: some View {
        NavigationStack {
            Picker(String(localized: "result.break_picker", defaultValue: "休憩時間"), selection: $customBreakMinutes) {
                ForEach(1...60, id: \.self) { Text(String(localized: "common.minutes_value", defaultValue: "\($0)分")).tag($0) }
            }
            .pickerStyle(.wheel)
            .navigationTitle(String(localized: "result.break_picker", defaultValue: "休憩時間"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(String(localized: "common.cancel", defaultValue: "キャンセル")) { showingCustomBreak = false } }
                ToolbarItem(placement: .confirmationAction) { Button(String(localized: "common.start", defaultValue: "開始")) { showingCustomBreak = false; startBreak(minutes: customBreakMinutes) } }
            }
            .presentationDetents([.medium])
        }
    }

    private var achievedMinutes: Int { max(Int(record.actualSeconds / 60), record.isCompleted ? record.plannedMinutes : 1) }
    private var divider: some View { Rectangle().fill(.white.opacity(0.09)).frame(width: 1, height: 48) }

    private func achievementMetric(_ label: String, _ value: String, _ symbol: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol).font(.caption).foregroundStyle(AppTheme.blue)
            Text(value).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.caption2).foregroundStyle(AppTheme.secondary)
        }.frame(maxWidth: .infinity)
    }

    private func summaryPill(_ label: String, _ value: String, _ symbol: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol).foregroundStyle(AppTheme.success)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.caption2).foregroundStyle(AppTheme.secondary)
                Text(value).font(.subheadline.monospacedDigit().weight(.medium))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: OrbitDesign.Radius.smallCard))
    }

    private func resultRow(_ label: String, _ value: String) -> some View { HStack { Text(label).foregroundStyle(AppTheme.secondary); Spacer(); Text(value).multilineTextAlignment(.trailing) }.font(.subheadline) }

    private func startBreak(minutes: Int) {
        sessionManager.startBreak(duration: TimeInterval(minutes * 60))
        router.show(.breakSession, missionID: mission.id)
    }

    private func repeatMission() {
        settings?.lastDurationMinutes = record.plannedMinutes
        settings?.lastDestination = record.destination
        settings?.flightDisplayMode = record.displayMode
        try? context.save()
        sessionManager.clearFinishedSession()
        router.repeatMission(focusTitle: record.focusTitle, durationMinutes: record.plannedMinutes, destination: record.destination)
    }
}
