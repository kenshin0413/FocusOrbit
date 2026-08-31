import Foundation
import Observation

enum AppScreen: Hashable {
    case introduction, home, roadmap, roadmapPass, roadmapLaunch, roadmapFocus, setup, missionPass, launch, flight, arrival, result, breakSession, logs, crew, settings
    case missionDetail(UUID)
}

struct MissionDraft {
    let focusTitle: String
    let durationMinutes: Int
    let destination: Destination
}

@MainActor @Observable
final class AppRouter {
    var screen: AppScreen = .home
    var missionID: UUID?
    var missionDraft: MissionDraft?
    func show(_ screen: AppScreen, missionID: UUID? = nil) {
        if let missionID { self.missionID = missionID }
        self.screen = screen
    }
    func startNewMission() {
        missionDraft = nil
        screen = .setup
    }
    func repeatMission(focusTitle: String, durationMinutes: Int, destination: Destination) {
        missionDraft = MissionDraft(focusTitle: focusTitle, durationMinutes: durationMinutes, destination: destination)
        screen = .setup
    }
    func returnHome() { missionID = nil; missionDraft = nil; screen = .home }
}
