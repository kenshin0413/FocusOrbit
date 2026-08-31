import SwiftData
import SwiftUI
import FirebaseCore


class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        FirebaseApp.app()?.isDataCollectionDefaultEnabled = true
        return true
    }
}

@main
struct FocusOrbitApp: App {
    @State private var sessionManager = FocusSessionManager()
    @State private var roadmapSessionManager = RoadmapSessionManager()
    @State private var appOpenAdManager = AppOpenAdManager()
    @State private var interstitialAdManager = InterstitialAdManager()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    private let container: ModelContainer = {
        let schema = Schema([Mission.self, MissionRecord.self, RoadmapFocusRecord.self, CrewProfile.self, AppSettings.self])
        do { return try ModelContainer(for: schema) }
        catch { fatalError("SwiftData container could not be created: \(error)") }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView(
                sessionManager: sessionManager,
                roadmapSessionManager: roadmapSessionManager,
                appOpenAdManager: appOpenAdManager,
                interstitialAdManager: interstitialAdManager
            )
            .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}
