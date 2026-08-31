import SwiftData
import SwiftUI

struct MissionDetailView: View {
    @Environment(\.modelContext) private var context
    let router: AppRouter
    let record: MissionRecord
    let crewName: String
    @State private var showingDeleteConfirmation = false

    private var mission: Mission {
        let mission = Mission(missionNumber: record.missionNumber, focusTitle: record.focusTitle, durationMinutes: record.plannedMinutes, destination: record.destination)
        mission.status = record.isCompleted ? .completed : .interrupted
        return mission
    }

    var body: some View {
        ScrollView {
            VStack(spacing: OrbitDesign.Spacing.section) {
                ScreenHeader(title: LocalizedRuntime.text(ja: "集中記録", en: "Focus Record"), subtitle: record.missionNumber) { router.show(.logs) }
                MissionPassCard(mission: mission, crewName: crewName, completed: record.isCompleted)
                details
                ratingEditor
                Button { repeatMission() } label: {
                    Label(LocalizedRuntime.text(ja: "同じ設定で再開始", en: "Start Again"), systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity, minHeight: OrbitDesign.Size.primaryButtonHeight)
                        .background(AppTheme.navigation, in: RoundedRectangle(cornerRadius: OrbitDesign.Radius.button))
                        .foregroundStyle(.black).fontWeight(.bold)
                }
                .buttonStyle(.plain)
                Button(LocalizedRuntime.text(ja: "この記録を削除", en: "Delete This Record"), role: .destructive) { showingDeleteConfirmation = true }
                    .frame(minHeight: OrbitDesign.Size.minimumTap)
            }
            .frame(maxWidth: OrbitDesign.Size.contentMaxWidth)
            .padding(OrbitDesign.Spacing.screenHorizontal)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .confirmationDialog(LocalizedRuntime.text(ja: "この集中記録を削除しますか？", en: "Delete this focus record?"), isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button(LocalizedRuntime.text(ja: "削除", en: "Delete"), role: .destructive, action: deleteRecord)
            Button(LocalizedRuntime.text(ja: "キャンセル", en: "Cancel"), role: .cancel) {}
        } message: { Text(LocalizedRuntime.text(ja: "統計からも除外されます。この操作は取り消せません。", en: "It will also be removed from your stats. This cannot be undone.")) }
    }

    private var details: some View {
        VStack(spacing: 12) {
            detail(LocalizedRuntime.text(ja: "開始日時", en: "Started At"), Formatters.dateTime.string(from: record.effectiveDate))
            detail(LocalizedRuntime.text(ja: "目的地", en: "Destination"), record.destination.name)
            detail(LocalizedRuntime.text(ja: "設定時間", en: "Planned Time"), LocalizedRuntime.text(ja: "\(record.plannedMinutes)分", en: "\(record.plannedMinutes) min"))
            detail(LocalizedRuntime.text(ja: "実際の集中時間", en: "Actual Focus Time"), Formatters.hoursMinutes(record.actualSeconds))
            detail(LocalizedRuntime.text(ja: "一時停止", en: "Pauses"), LocalizedRuntime.text(ja: "\(record.pauseCount)回", en: "\(record.pauseCount)"))
            detail(LocalizedRuntime.text(ja: "表示モード", en: "Display Mode"), record.displayMode.japaneseTitle)
            detail(LocalizedRuntime.text(ja: "方式", en: "Mode"), record.isPomodoro ? LocalizedRuntime.text(ja: "ポモドーロ 第\(record.pomodoroCycle)サイクル", en: "Pomodoro Cycle \(record.pomodoroCycle)") : LocalizedRuntime.text(ja: "通常の集中", en: "Standard Focus"))
            detail(LocalizedRuntime.text(ja: "ステータス", en: "Status"), record.isCompleted ? LocalizedRuntime.text(ja: "完了", en: "Completed") : LocalizedRuntime.text(ja: "中断", en: "Interrupted"))
            detail(LocalizedRuntime.text(ja: "航行距離", en: "Flight Distance"), Formatters.distance(record.distanceKilometers))
        }.spacePanel()
    }

    private var ratingEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedRuntime.text(ja: "集中評価", en: "Focus Rating")).font(.headline)
            ForEach([FocusRating.focused, .somewhat, .distracted]) { rating in
                Button {
                    record.rating = rating
                    try? context.save()
                } label: {
                    HStack {
                        Text(rating.title)
                        Spacer()
                        Image(systemName: record.rating == rating ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(record.rating == rating ? AppTheme.success : AppTheme.secondary)
                    }
                    .frame(minHeight: OrbitDesign.Size.minimumTap)
                }
                .buttonStyle(.plain)
            }
        }.spacePanel()
    }

    private func detail(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(AppTheme.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }.font(.subheadline)
    }

    private func repeatMission() {
        router.repeatMission(focusTitle: record.focusTitle, durationMinutes: record.plannedMinutes, destination: record.destination)
    }

    private func deleteRecord() {
        context.delete(record)
        try? context.save()
        router.show(.logs)
    }
}
