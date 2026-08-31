import SwiftData
import SwiftUI

struct FlightView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    let router: AppRouter
    let mission: Mission
    let settings: AppSettings?
    let sessionManager: FocusSessionManager
    @State private var viewModel: FlightViewModel?

    var body: some View {
        Group {
            if let viewModel {
                flightContent(viewModel)
            } else {
                ProgressView().tint(.white)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .statusBarHidden(true)
        .task {
            guard viewModel == nil else { return }
            let model = FlightViewModel(mission: mission, context: context, sessionManager: sessionManager)
            viewModel = model
            model.begin(settings: settings)
        }
        .onDisappear {
            if mission.status != .flying && mission.status != .paused { viewModel?.cleanup() }
        }
    }

    private func flightContent(_ model: FlightViewModel) -> some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width > proxy.size.height * 1.12
            let mode = sessionManager.displayMode.resolved
            ZStack {
                FlightSceneView(
                    destination: mission.destination,
                    fallbackProgress: model.progress,
                    scheduledEndAt: sessionManager.session?.scheduledEndAt,
                    totalSeconds: sessionManager.session?.configuredDuration ?? mission.totalSeconds,
                    phase: model.phase,
                    displayMode: mode,
                    isPaused: sessionManager.isPaused,
                    isActive: scenePhase == .active,
                    darkRoomMode: settings?.darkRoomModeEnabled ?? false
                )

                Group {
                    if isWide {
                        landscapeHUD(model, mode: mode, safeArea: proxy.safeAreaInsets)
                    } else {
                        portraitHUD(model, mode: mode, safeArea: proxy.safeAreaInsets)
                    }
                }
                .opacity(finalApproachHUDOpacity(model))

                if sessionManager.isPaused {
                    Color.black.opacity(0.48).ignoresSafeArea()
                    FlightPausePanel(
                        displayMode: displayModeBinding,
                        resume: { model.togglePause() },
                        end: { model.showInterruptionDialog = true }
                    )
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.97)))
                }
            }
            .ignoresSafeArea()
            .animation(.easeInOut(duration: reduceMotion ? 0.18 : 0.35), value: sessionManager.isPaused)
            .onChange(of: model.didFinish) { _, finished in
                if finished { router.show(mission.status == .completed ? .arrival : .result) }
            }
            .onChange(of: sessionManager.status) { _, status in
                model.handleManagerUpdate()
                if status == .completed { router.show(.arrival) }
            }
            .onChange(of: sessionManager.phase) { oldPhase, newPhase in
                model.handleManagerUpdate()
                if oldPhase != newPhase, newPhase == .orbitDeparture || newPhase == .orbitalInsertion {
                    MissionHaptics.orbitInsertion(enabled: settings?.hapticsEnabled ?? true, reduceMotion: reduceMotion)
                }
            }
            .confirmationDialog(
                String(localized: "flight.interrupt.confirmation", defaultValue: "航行を中断しますか？"),
                isPresented: Binding(get: { model.showInterruptionDialog }, set: { model.showInterruptionDialog = $0 }),
                titleVisibility: .visible
            ) {
                Button(String(localized: "flight.continue", defaultValue: "航行を続ける"), role: .cancel) {}
                Button(String(localized: "common.interrupt", defaultValue: "中断する"), role: .destructive) { model.interrupt() }
            } message: {
                Text(String(localized: "flight.interrupt.detail", defaultValue: "現在の記録は未完了として保存されます"))
            }
        }
    }

    private func finalApproachHUDOpacity(_ model: FlightViewModel) -> Double {
        let duration = max(sessionManager.session?.configuredDuration ?? mission.totalSeconds, 1)
        let approach = MissionVisualGeometry.arrivalProgress(missionProgress: model.progress, totalSeconds: duration)
        return 1 - MissionVisualGeometry.eased(min(approach / 0.42, 1))
    }

    private func portraitHUD(
        _ model: FlightViewModel,
        mode: FocusDisplayMode,
        safeArea: EdgeInsets
    ) -> some View {
        VStack(spacing: 0) {
            flightIdentity(model, centered: mode == .cinematic)
                .padding(.horizontal, 20)
                .padding(.top, max(safeArea.top + 14, 30))
            Spacer(minLength: 20)
            if model.shouldShowTransitMessage && mode != .audioOnly && mode != .simple {
                announcementPill(model.transitMessage)
                    .padding(.bottom, 10)
                    .transition(.opacity)
            }
            switch mode {
            case .cockpit:
                primaryHUDPanel(model, compact: true, bottomInset: safeArea.bottom)
            case .cinematic:
                cinematicHUD(model, bottomInset: safeArea.bottom)
            case .simple, .minimal:
                simpleHUD(model, bottomInset: safeArea.bottom)
            case .audioOnly:
                audioOnlyHUD(model, bottomInset: safeArea.bottom)
            }
        }
    }

    private func landscapeHUD(
        _ model: FlightViewModel,
        mode: FocusDisplayMode,
        safeArea: EdgeInsets
    ) -> some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading) {
                flightIdentity(model, centered: false)
                Spacer()
                if model.shouldShowTransitMessage && mode == .cockpit {
                    announcementPill(model.transitMessage)
                }
            }
            .padding(.leading, max(safeArea.leading + 22, 28))
            .padding(.top, max(safeArea.top + 18, 28))
            .padding(.bottom, max(safeArea.bottom + 18, 24))

            Spacer(minLength: 80)

            VStack {
                Spacer(minLength: max(safeArea.top, 16))
                landscapePanel(model, mode: mode)
                    .frame(maxWidth: mode == .cinematic ? 340 : 410)
                Spacer(minLength: max(safeArea.bottom, 16))
            }
            .padding(.trailing, max(safeArea.trailing + 22, 28))
        }
    }

    private func flightIdentity(_ model: FlightViewModel, centered: Bool) -> some View {
        VStack(alignment: centered ? .center : .leading, spacing: 4) {
            Text(mission.focusTitle)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.36), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.10)))
            Text(String(localized: "flight.in_progress", defaultValue: "\(mission.destination.name)へ航行中"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text(String(localized: "flight.phase_destination", defaultValue: "\(model.phase.englishTitle)  ·  \(mission.destination.englishName)"))
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .tracking(1.3)
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
        }
        .frame(maxWidth: centered ? .infinity : nil, alignment: centered ? .center : .leading)
        .shadow(color: .black.opacity(0.8), radius: 10)
        .accessibilityElement(children: .combine)
    }

    private func primaryHUDPanel(_ model: FlightViewModel, compact: Bool, bottomInset: CGFloat) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                hudChip(model.phase.japaneseTitle, tint: mission.destination.accent)
                hudChip(sessionManager.displayMode.resolved.japaneseTitle, tint: AppTheme.blue)
                Spacer()
            }
            HStack(alignment: .bottom, spacing: 14) {
                FlightRemainingTimeView(remainingSeconds: model.remainingSeconds, arrivalDate: sessionManager.session?.scheduledEndAt, compact: compact)
                    .frame(maxWidth: .infinity, alignment: .leading)
                FlightPauseButton(isPaused: false) { model.togglePause() }
            }
            FlightRouteProgressView(destination: mission.destination, phase: model.phase, progress: model.progress, compact: compact)
            FlightTelemetrySummary(
                destination: mission.destination,
                remainingDistance: model.remainingDistance,
                elapsedSeconds: model.elapsedSeconds,
                arrivalDate: sessionManager.session?.scheduledEndAt,
                detailed: settings?.detailedFlightDataEnabled ?? false
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, max(bottomInset, 12))
        .background(hudBackground)
        .overlay(alignment: .top) { accentLine }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 25, topTrailingRadius: 25))
        .frame(maxWidth: 720)
    }

    private func cinematicHUD(_ model: FlightViewModel, bottomInset: CGFloat) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                hudChip(mission.focusTitle, tint: mission.destination.accent)
                Spacer()
                hudChip(model.phase.japaneseTitle, tint: .white)
            }
            HStack(spacing: 18) {
                FlightRemainingTimeView(remainingSeconds: model.remainingSeconds, arrivalDate: sessionManager.session?.scheduledEndAt, compact: true)
                FlightRouteProgressView(destination: mission.destination, phase: model.phase, progress: model.progress, compact: true)
                    .frame(maxWidth: 290)
                FlightPauseButton(isPaused: false) { model.togglePause() }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, max(bottomInset, 12))
        .background(.black.opacity(0.58))
        .overlay(alignment: .top) { accentLine }
        .frame(maxWidth: 760)
    }

    private func simpleHUD(_ model: FlightViewModel, bottomInset: CGFloat) -> some View {
        VStack(spacing: 12) {
            HStack {
                hudChip(mission.focusTitle, tint: mission.destination.accent)
                Spacer()
            }
            HStack(alignment: .bottom) {
                FlightRemainingTimeView(remainingSeconds: model.remainingSeconds, arrivalDate: sessionManager.session?.scheduledEndAt)
                Spacer(minLength: 12)
                FlightPauseButton(isPaused: false) { model.togglePause() }
            }
            FlightRouteProgressView(destination: mission.destination, phase: model.phase, progress: model.progress)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, max(bottomInset, 14))
        .background(hudBackground)
        .frame(maxWidth: 720)
    }

    private func audioOnlyHUD(_ model: FlightViewModel, bottomInset: CGFloat) -> some View {
        HStack(alignment: .bottom) {
            FlightRemainingTimeView(remainingSeconds: model.remainingSeconds, arrivalDate: sessionManager.session?.scheduledEndAt, compact: true, subdued: true)
            Spacer()
            FlightPauseButton(isPaused: false) { model.togglePause() }
                .opacity(0.62)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, max(bottomInset + 12, 24))
        .frame(maxWidth: 680)
    }

    private func landscapePanel(_ model: FlightViewModel, mode: FocusDisplayMode) -> some View {
        VStack(spacing: mode == .cinematic ? 11 : 15) {
            HStack(spacing: 8) {
                hudChip(model.phase.japaneseTitle, tint: mission.destination.accent)
                Spacer()
                if mode != .audioOnly {
                    hudChip(mission.focusTitle, tint: .white)
                }
            }
            HStack(alignment: .bottom) {
                FlightRemainingTimeView(
                    remainingSeconds: model.remainingSeconds,
                    arrivalDate: sessionManager.session?.scheduledEndAt,
                    compact: mode == .cinematic || mode == .audioOnly,
                    subdued: mode == .audioOnly
                )
                Spacer(minLength: 12)
                FlightPauseButton(isPaused: false) { model.togglePause() }
            }
            FlightRouteProgressView(destination: mission.destination, phase: model.phase, progress: model.progress, compact: true)
            if mode == .cockpit {
                FlightTelemetrySummary(
                    destination: mission.destination,
                    remainingDistance: model.remainingDistance,
                    elapsedSeconds: model.elapsedSeconds,
                    arrivalDate: sessionManager.session?.scheduledEndAt,
                    detailed: settings?.detailedFlightDataEnabled ?? false
                )
            }
        }
        .padding(18)
        .background(
            mode == .audioOnly ? AnyShapeStyle(Color.black.opacity(0.82)) : AnyShapeStyle(.ultraThinMaterial),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppTheme.line))
    }

    private func announcementPill(_ message: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "speaker.wave.2.fill").font(.caption2).foregroundStyle(mission.destination.accent)
            Text(message).font(.caption).tracking(0.5)
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(.black.opacity(0.68), in: Capsule())
        .overlay(Capsule().stroke(mission.destination.accent.opacity(0.28)))
        .accessibilityElement(children: .combine)
    }

    private var displayModeBinding: Binding<FocusDisplayMode> {
        Binding(
            get: { sessionManager.displayMode.resolved },
            set: { mode in
                sessionManager.updateDisplayMode(mode)
                settings?.flightDisplayMode = mode
                try? context.save()
            }
        )
    }

    private var hudBackground: some ShapeStyle {
        LinearGradient(
            colors: [Color(red: 0.025, green: 0.045, blue: 0.075).opacity(0.92), Color.black.opacity(0.94)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var accentLine: some View {
        Rectangle()
            .fill(LinearGradient(colors: [.clear, mission.destination.accent.opacity(0.58), .clear], startPoint: .leading, endPoint: .trailing))
            .frame(height: 1)
    }

    private func hudChip(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.13), in: Capsule())
            .overlay(Capsule().stroke(tint.opacity(0.22)))
            .foregroundStyle(tint == .white ? .white.opacity(0.82) : tint)
    }
}

#Preview("Cockpit") {
    FlightPreviewHost(mode: .cockpit)
}

#Preview("Cinematic") {
    FlightPreviewHost(mode: .cinematic)
}

private struct FlightPreviewHost: View {
    let mode: FocusDisplayMode
    private let mission = Mission(missionNumber: "MS-0048", focusTitle: "経済学レポート", durationMinutes: 45, destination: .mars)

    var body: some View {
        FlightView(
            router: AppRouter(),
            mission: mission,
            settings: AppSettings(),
            sessionManager: .preview(progress: 0.42, destination: .mars, displayMode: mode)
        )
            .modelContainer(for: [Mission.self, MissionRecord.self, CrewProfile.self, AppSettings.self], inMemory: true)
    }
}
