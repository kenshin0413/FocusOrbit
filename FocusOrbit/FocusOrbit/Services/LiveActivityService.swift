#if canImport(ActivityKit)
import ActivityKit
import Foundation

@MainActor
final class LiveActivityService {
    static let shared = LiveActivityService()
    private var activity: Activity<FocusOrbitActivityAttributes>?

    var isSupported: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    func start(for session: FocusSession, phase: MissionPhase) async {
        guard isSupported, !session.status.isBreak else { return }
        if let existing = Activity<FocusOrbitActivityAttributes>.activities.first(where: { $0.attributes.sessionID == session.id }) {
            activity = existing
            await update(session: session, phase: phase)
            return
        }
        let attributes = FocusOrbitActivityAttributes(
            sessionID: session.id,
            destinationName: session.destination.name,
            destinationEnglishName: session.destination.englishName
        )
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: contentState(session: session, phase: phase), staleDate: session.scheduledEndAt),
                pushType: nil
            )
        } catch {
            activity = nil
        }
    }

    func update(session: FocusSession, phase: MissionPhase) async {
        guard isSupported else { return }
        if activity == nil {
            activity = Activity<FocusOrbitActivityAttributes>.activities.first(where: { $0.attributes.sessionID == session.id })
        }
        guard let activity else {
            await start(for: session, phase: phase)
            return
        }
        await activity.update(ActivityContent(state: contentState(session: session, phase: phase), staleDate: session.scheduledEndAt))
    }

    func end(session: FocusSession, phase: MissionPhase) async {
        let finalContent = ActivityContent(state: contentState(session: session, phase: phase), staleDate: nil)
        let matching = Activity<FocusOrbitActivityAttributes>.activities.filter { $0.attributes.sessionID == session.id }
        for item in matching { await item.end(finalContent, dismissalPolicy: .default) }
        activity = nil
    }

    func restore(for session: FocusSession, phase: MissionPhase) async {
        activity = Activity<FocusOrbitActivityAttributes>.activities.first(where: { $0.attributes.sessionID == session.id })
        if session.status.isActive {
            if activity == nil { await start(for: session, phase: phase) }
            else { await update(session: session, phase: phase) }
        } else if activity != nil {
            await end(session: session, phase: phase)
        }
    }

    private func contentState(session: FocusSession, phase: MissionPhase) -> FocusOrbitActivityAttributes.ContentState {
        FocusOrbitActivityAttributes.ContentState(
            scheduledEndAt: session.scheduledEndAt,
            remainingAtPause: session.lastKnownRemaining,
            isPaused: session.status.isPaused,
            progress: session.lastKnownProgress,
            phaseJapanese: phase.japaneseTitle,
            phaseEnglish: phase.englishTitle
        )
    }
}
#else
import Foundation

@MainActor
final class LiveActivityService {
    static let shared = LiveActivityService()
    var isSupported: Bool { false }
    func start(for session: FocusSession, phase: MissionPhase) async {}
    func update(session: FocusSession, phase: MissionPhase) async {}
    func end(session: FocusSession, phase: MissionPhase) async {}
    func restore(for session: FocusSession, phase: MissionPhase) async {}
}
#endif
