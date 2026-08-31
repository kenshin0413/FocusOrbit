import Foundation
import Observation

struct RoadmapActiveSession: Codable, Equatable {
    var id: UUID
    var startedAt: Date
    var pauseStartedAt: Date?
    var accumulatedPausedDuration: TimeInterval
    var pauseCount: Int

    func elapsedSeconds(at date: Date) -> TimeInterval {
        let effectiveDate = pauseStartedAt ?? date
        return max(effectiveDate.timeIntervalSince(startedAt) - accumulatedPausedDuration, 0)
    }
}

struct CompletedRoadmapSession {
    let id: UUID
    let startedAt: Date
    let completedAt: Date
    let focusedSeconds: TimeInterval
    let pauseCount: Int
}

enum RoadmapPreflightStage: String {
    case pass, launch
}

private struct RoadmapJourneyState: Codable {
    var hasPresentedInitialLaunch = false
    var acknowledgedDestinationCount = 0
    var pendingSurfaceDepartureIndex: Int?
}

@MainActor @Observable
final class RoadmapSessionManager {
    private(set) var session: RoadmapActiveSession?
    private(set) var now = Date()
    private(set) var elapsedSeconds: TimeInterval = 0

    private let defaults: UserDefaults
    private let sessionKey = "focusOrbit.roadmapSession.v1"
    private let journeyKey = "focusOrbit.roadmapJourney.v1"
    private let preflightKey = "focusOrbit.roadmapPreflight.v1"
    private var journeyState: RoadmapJourneyState
    private var tickerTask: Task<Void, Never>?
    private var applicationIsActive = true

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: journeyKey),
           let restored = try? JSONDecoder().decode(RoadmapJourneyState.self, from: data) {
            journeyState = restored
        } else {
            journeyState = RoadmapJourneyState()
        }
    }

    var isActive: Bool { session != nil }
    var isPaused: Bool { session?.pauseStartedAt != nil }
    var needsInitialLaunch: Bool { !journeyState.hasPresentedInitialLaunch }
    var acknowledgedDestinationCount: Int { journeyState.acknowledgedDestinationCount }
    var pendingSurfaceDepartureIndex: Int? { journeyState.pendingSurfaceDepartureIndex }
    var preflightStage: RoadmapPreflightStage? {
        defaults.string(forKey: preflightKey).flatMap(RoadmapPreflightStage.init(rawValue:))
    }

    func beginPreflight() { defaults.set(RoadmapPreflightStage.pass.rawValue, forKey: preflightKey) }
    func markPreflightAuthorized() { defaults.set(RoadmapPreflightStage.launch.rawValue, forKey: preflightKey) }
    func cancelPreflight() { defaults.removeObject(forKey: preflightKey) }

    func acknowledgeInitialLaunch() {
        journeyState.hasPresentedInitialLaunch = true
        persistJourneyState()
    }

    func acknowledgeDestinations(upTo count: Int) {
        journeyState.acknowledgedDestinationCount = min(max(count, 0), RoadmapRoute.legs.count)
        persistJourneyState()
    }

    func beginSurfaceDepartureCheckpoint(at index: Int) {
        guard RoadmapRoute.legs.indices.contains(index) else { return }
        journeyState.pendingSurfaceDepartureIndex = index
        persistJourneyState()
    }

    func completeSurfaceDepartureCheckpoint() {
        guard let index = journeyState.pendingSurfaceDepartureIndex else { return }
        journeyState.acknowledgedDestinationCount = min(index + 1, RoadmapRoute.legs.count)
        journeyState.pendingSurfaceDepartureIndex = nil
        persistJourneyState()
    }

    func startSession(at date: Date = .now) {
        guard session == nil else { return }
        session = RoadmapActiveSession(
            id: UUID(),
            startedAt: date,
            pauseStartedAt: nil,
            accumulatedPausedDuration: 0,
            pauseCount: 0
        )
        cancelPreflight()
        refresh(at: date, persist: true)
        startTickerIfNeeded()
    }

    func pauseSession(at date: Date = .now) {
        guard var session, session.pauseStartedAt == nil else { return }
        refresh(at: date)
        session.pauseStartedAt = date
        session.pauseCount += 1
        self.session = session
        refresh(at: date, persist: true)
        tickerTask?.cancel()
        tickerTask = nil
    }

    func resumeSession(at date: Date = .now) {
        guard var session, let pauseStartedAt = session.pauseStartedAt else { return }
        session.accumulatedPausedDuration += max(date.timeIntervalSince(pauseStartedAt), 0)
        session.pauseStartedAt = nil
        self.session = session
        refresh(at: date, persist: true)
        startTickerIfNeeded()
    }

    func finishSession(at date: Date = .now) -> CompletedRoadmapSession? {
        guard let session else { return nil }
        let elapsed = session.elapsedSeconds(at: date)
        let completed = CompletedRoadmapSession(
            id: session.id,
            startedAt: session.startedAt,
            completedAt: date,
            focusedSeconds: elapsed,
            pauseCount: session.pauseCount
        )
        tickerTask?.cancel()
        tickerTask = nil
        self.session = nil
        elapsedSeconds = 0
        defaults.removeObject(forKey: sessionKey)
        return completed
    }

    func restoreSession(at date: Date = .now) {
        guard session == nil,
              let data = defaults.data(forKey: sessionKey),
              let restored = try? JSONDecoder().decode(RoadmapActiveSession.self, from: data) else { return }
        session = restored
        refresh(at: date)
        startTickerIfNeeded()
    }

    func setApplicationActive(_ active: Bool, at date: Date = .now) {
        applicationIsActive = active
        refresh(at: date, persist: true)
        if active { startTickerIfNeeded() }
        else {
            tickerTask?.cancel()
            tickerTask = nil
        }
    }

    private func startTickerIfNeeded() {
        guard applicationIsActive, session != nil, !isPaused else { return }
        tickerTask?.cancel()
        tickerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                self.refresh(at: .now)
            }
        }
    }

    private func refresh(at date: Date, persist: Bool = false) {
        now = date
        elapsedSeconds = session?.elapsedSeconds(at: date) ?? 0
        if persist, let session, let data = try? JSONEncoder().encode(session) {
            defaults.set(data, forKey: sessionKey)
        }
    }

    private func persistJourneyState() {
        guard let data = try? JSONEncoder().encode(journeyState) else { return }
        defaults.set(data, forKey: journeyKey)
    }
}
