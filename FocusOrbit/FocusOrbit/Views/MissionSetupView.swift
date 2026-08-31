import SwiftData
import SwiftUI

struct MissionSetupView: View {
    @Environment(\.modelContext) private var context
    let router: AppRouter
    let existingCount: Int
    let settings: AppSettings?
    let records: [MissionRecord]
    @State private var viewModel: MissionSetupViewModel
    @FocusState private var focusFieldIsActive: Bool

    init(
        router: AppRouter,
        existingCount: Int,
        settings: AppSettings? = nil,
        records: [MissionRecord] = [],
        initialDraft: MissionDraft? = nil
    ) {
        self.router = router
        self.existingCount = existingCount
        self.settings = settings
        self.records = records
        _viewModel = State(initialValue: MissionSetupViewModel(
            draft: initialDraft,
            lastDuration: settings?.lastDurationMinutes ?? 25,
            lastDestination: settings?.lastDestination ?? .moon,
            titleHistory: settings?.focusTitleHistory ?? [],
            durationHistory: settings?.durationHistoryMinutes ?? []
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OrbitDesign.Spacing.section) {
                ScreenHeader(title: LocalizedRuntime.text(ja: "カスタム航行設定", en: "Custom Flight Setup"), subtitle: "PRE-FLIGHT CONFIGURATION") { router.returnHome() }
                missionPreviewCard
                focusSection
                durationSection
                PomodoroSetupView(model: viewModel)
                destinationSection
                if settings != nil { displaySection }
            }
            .frame(maxWidth: OrbitDesign.Size.contentMaxWidth)
            .padding(.horizontal, OrbitDesign.Spacing.screenHorizontal)
            .padding(.top, 8)
            .padding(.bottom, 100)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) { issueButtonBar }
    }

    private var missionPreviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("LIVE PREVIEW")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(AppTheme.blue)
                    Text(viewModel.focusTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? LocalizedRuntime.text(ja: "集中内容を入力してください", en: "Enter a focus topic") : viewModel.focusTitle)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)
                    Text(LocalizedRuntime.text(ja: "開始前に内容・時間・目的地をひと目で確認", en: "Review topic, time, and destination before launch"))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondary)
                }
                Spacer()
                CelestialBodyView(kind: .destination(viewModel.destination))
                    .frame(width: 62, height: 62)
            }
            HStack(spacing: 10) {
                previewPill(Formatters.hoursMinutes(TimeInterval(viewModel.durationMinutes * 60)), symbol: "timer")
                previewPill(viewModel.destination.name, symbol: "location.north.circle")
                if viewModel.usesPomodoro {
                    previewPill(LocalizedRuntime.text(ja: "\(viewModel.cycleCount)サイクル", en: "\(viewModel.cycleCount) cycles"), symbol: "repeat")
                }
            }
        }
        .spacePanel()
    }

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(LocalizedRuntime.text(ja: "集中内容", en: "Focus Topic"), english: "FOCUS")
            TextField(LocalizedRuntime.text(ja: "例：経済学レポート", en: "Example: Economics report"), text: $viewModel.focusTitle)
                .focused($focusFieldIsActive)
                .submitLabel(.done)
                .textFieldStyle(.plain)
                .padding(16)
                .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: OrbitDesign.Radius.button))
                .overlay(RoundedRectangle(cornerRadius: OrbitDesign.Radius.button).stroke(AppTheme.line))
                .accessibilityLabel(LocalizedRuntime.text(ja: "集中内容", en: "Focus Topic"))
            if !viewModel.titleHistory.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.titleHistory, id: \.self) { title in
                            Button { viewModel.focusTitle = title } label: {
                                Text(title)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 9)
                                    .background(.white.opacity(0.05), in: Capsule())
                                    .overlay(Capsule().stroke(.white.opacity(0.08)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(LocalizedRuntime.text(ja: "集中時間", en: "Focus Duration"), english: "DURATION")
            FocusDurationPicker(
                selection: $viewModel.durationMinutes,
                savedDurations: viewModel.durationHistory
            )
        }
    }

    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(String(localized: "mission.destination", defaultValue: "目的地"), english: "DESTINATION")
            Text(String(localized: "mission_setup.destination_hint", defaultValue: "\(Formatters.hoursMinutes(TimeInterval(viewModel.durationMinutes * 60)))に合う目的地を先に表示しています"))
                .font(.caption).foregroundStyle(AppTheme.secondary)
            DestinationSelectView(
                selection: $viewModel.destination,
                durationMinutes: viewModel.durationMinutes,
                visitedDestinations: Set(records.filter(\.isCompleted).map(\.destination)),
                completedCounts: Dictionary(
                    grouping: records.filter { $0.isFocusRecord && $0.isCompleted },
                    by: \.destination
                ).mapValues(\.count)
            )
        }
    }

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(LocalizedRuntime.text(ja: "航行中の表示", en: "In-Flight Display"), english: "DISPLAY MODE")
            FocusDisplayModePicker(selection: displayModeBinding)
            Text(LocalizedRuntime.text(ja: "集中開始後は、一時停止中のみ変更できます", en: "You can change this only while paused after focus starts"))
                .font(.caption2).foregroundStyle(AppTheme.secondary)
        }
    }

    private var issueButtonBar: some View {
        VStack(spacing: 0) {
            Divider().overlay(AppTheme.line)
            Button { issuePass() } label: {
                Label(LocalizedRuntime.text(ja: "ミッションパスを発行", en: "Issue Mission Pass"), systemImage: "ticket")
                    .frame(maxWidth: .infinity, minHeight: OrbitDesign.Size.primaryButtonHeight)
                    .background(viewModel.canCreate ? AppTheme.navigation : Color.gray.opacity(0.34), in: RoundedRectangle(cornerRadius: OrbitDesign.Radius.button))
                    .foregroundStyle(.black)
                    .fontWeight(.bold)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canCreate)
            .accessibilityHint(LocalizedRuntime.text(ja: "設定内容を確認するミッションパスへ進みます", en: "Opens the mission pass to confirm your settings"))
            .padding(.horizontal, OrbitDesign.Spacing.screenHorizontal)
            .padding(.vertical, 10)
            .frame(maxWidth: OrbitDesign.Size.contentMaxWidth)
        }
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }

    private func previewPill(_ title: String, symbol: String) -> some View {
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

    private func sectionHeader(_ title: String, english: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(OrbitDesign.Typography.sectionTitle)
            Spacer()
            Text(english).font(OrbitDesign.Typography.spaceLabel).tracking(1.2).foregroundStyle(AppTheme.secondary)
        }
    }

    private var displayModeBinding: Binding<FocusDisplayMode> {
        Binding(
            get: { settings?.flightDisplayMode ?? .cockpit },
            set: { mode in settings?.flightDisplayMode = mode; try? context.save() }
        )
    }

    private func issuePass() {
        focusFieldIsActive = false
        let mission = Mission(
            missionNumber: String(format: "MS-%04d", existingCount + 1),
            focusTitle: viewModel.focusTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            durationMinutes: viewModel.durationMinutes,
            destination: viewModel.destination,
            pomodoro: viewModel.pomodoroConfiguration
        )
        settings?.lastDurationMinutes = viewModel.durationMinutes
        settings?.lastDestination = viewModel.destination
        settings?.rememberFocusTitle(mission.focusTitle)
        settings?.rememberDurationMinutes(viewModel.durationMinutes)
        if viewModel.usesPomodoro {
            settings?.pomodoroFocusMinutes = viewModel.durationMinutes
            settings?.pomodoroBreakMinutes = viewModel.breakMinutes
            settings?.pomodoroCycles = viewModel.cycleCount
            settings?.pomodoroLongBreakMinutes = viewModel.longBreakMinutes
            settings?.pomodoroLongBreakEvery = viewModel.longBreakEvery
            settings?.pomodoroAutoStartBreak = viewModel.automaticallyStartBreak
            settings?.pomodoroAutoStartFocus = viewModel.automaticallyStartNextFocus
        }
        context.insert(mission)
        try? context.save()
        Task { await NotificationService.shared.requestAuthorization() }
        router.show(.missionPass, missionID: mission.id)
    }
}

struct ScreenHeader: View {
    let title: String
    let subtitle: String
    let back: () -> Void
    var body: some View {
        HStack {
            Button(action: back) {
                Image(systemName: "chevron.left")
                    .frame(width: OrbitDesign.Size.minimumTap, height: OrbitDesign.Size.minimumTap)
                    .background(AppTheme.panel, in: Circle())
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title2.weight(.semibold))
                Text(subtitle).font(OrbitDesign.Typography.spaceLabel).tracking(1.3).foregroundStyle(AppTheme.secondary)
            }
            Spacer()
        }
        .buttonStyle(.plain)
    }
}
