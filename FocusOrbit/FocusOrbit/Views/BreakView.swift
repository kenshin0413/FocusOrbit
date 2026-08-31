import SwiftData
import SwiftUI

struct BreakView: View {
    @Environment(\.modelContext) private var context
    let router: AppRouter
    let sessionManager: FocusSessionManager
    let mission: Mission
    let settings: AppSettings?
    let recordCount: Int
    @State private var handledCompletion = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.015, green: 0.035, blue: 0.07), .black], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 22) {
                VStack(spacing: 10) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 36)).foregroundStyle(AppTheme.transit)
                    VStack(spacing: 4) {
                        Text(LocalizedRuntime.text(ja: "休憩中", en: "On Break")).font(.title2.weight(.semibold))
                        Text("CABIN REST").font(OrbitDesign.Typography.spaceLabel).tracking(1.5).foregroundStyle(AppTheme.secondary)
                    }
                }
                VStack(spacing: 14) {
                    Text(Formatters.countdown(sessionManager.remainingSeconds))
                        .font(.system(size: 66, weight: .ultraLight, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                    HStack(spacing: 10) {
                        breakPill(mission.focusTitle, symbol: "text.quote")
                        breakPill(LocalizedRuntime.text(ja: "\(mission.destination.name)行き", en: "To \(mission.destination.name)"), symbol: "location.north.line")
                    }
                }
                VStack(spacing: 8) {
                    Text(LocalizedRuntime.text(ja: "次の集中に備えて、画面操作は必要ありません", en: "No input is needed while you prepare for the next focus session"))
                        .font(.subheadline).foregroundStyle(AppTheme.secondary)
                        .multilineTextAlignment(.center)
                    if sessionManager.session?.pomodoroConfiguration?.automaticallyStartNextFocus == true {
                        Text(LocalizedRuntime.text(ja: "休憩終了後は自動で次のサイクルへ戻ります", en: "The next cycle will start automatically after this break"))
                            .font(.caption)
                            .foregroundStyle(AppTheme.blue)
                    }
                }
                Button(LocalizedRuntime.text(ja: "休憩を終了", en: "End Break")) {
                    sessionManager.cancelSession()
                }
                .frame(maxWidth: .infinity, minHeight: OrbitDesign.Size.minimumTap)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: OrbitDesign.Radius.button))
                .overlay(RoundedRectangle(cornerRadius: OrbitDesign.Radius.button).stroke(.white.opacity(0.10)))
                .foregroundStyle(.white)
            }
            .padding(28)
            .frame(maxWidth: 520)
            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white.opacity(0.08)))
            .padding(24)
        }
        .statusBarHidden(true)
        .onChange(of: sessionManager.status) { _, status in
            if status == .completed || status == .cancelled { finishBreak() }
        }
        .task {
            if sessionManager.status == .completed || sessionManager.status == .cancelled { finishBreak() }
        }
    }

    private func finishBreak() {
        guard !handledCompletion, let finishedBreak = sessionManager.session else { return }
        handledCompletion = true
        saveBreakRecord(finishedBreak)
        guard let finishedBreak = sessionManager.session,
              let pomodoro = finishedBreak.pomodoroConfiguration,
              pomodoro.automaticallyStartNextFocus,
              finishedBreak.currentCycle < pomodoro.cycleCount else {
            sessionManager.clearFinishedSession()
            router.returnHome()
            return
        }
        let nextCycle = finishedBreak.currentCycle + 1
        let nextMission = Mission(
            missionNumber: String(format: "MS-%04d", recordCount + 1),
            focusTitle: mission.focusTitle,
            durationMinutes: max(Int(pomodoro.focusDuration / 60), 1),
            destination: mission.destination,
            pomodoro: pomodoro
        )
        context.insert(nextMission)
        try? context.save()
        sessionManager.clearFinishedSession()
        sessionManager.startSession(
            missionID: nextMission.id,
            duration: pomodoro.focusDuration,
            destination: nextMission.destination,
            displayMode: settings?.flightDisplayMode ?? .cockpit,
            pomodoro: pomodoro,
            currentCycle: nextCycle
        )
        router.show(.flight, missionID: nextMission.id)
    }

    private func saveBreakRecord(_ session: FocusSession) {
        let sessionID = session.id
        let descriptor = FetchDescriptor<MissionRecord>(predicate: #Predicate { $0.sessionID == sessionID })
        guard (try? context.fetchCount(descriptor)) == 0 else { return }
        let actualSeconds = min(max(session.lastKnownElapsed, 0), session.configuredDuration)
        context.insert(MissionRecord(
            mission: mission,
            actualSeconds: actualSeconds,
            completed: session.status == .completed,
            pauseCount: session.pauseCount,
            displayMode: .simple,
            kind: .breakTime,
            session: session,
            wasAutomaticallyStarted: mission.automaticallyStartBreak
        ))
        try? context.save()
    }

    private func breakPill(_ title: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
            Text(title)
                .lineLimit(1)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.white.opacity(0.05), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.08)))
        .foregroundStyle(AppTheme.secondary)
    }
}
