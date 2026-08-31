import AppTrackingTransparency
import GoogleMobileAds
import UIKit

@MainActor
final class TrackingAuthorizationManager {
    static let shared = TrackingAuthorizationManager()

    private var hasStartedMobileAds = false

    private init() {}

    func requestTrackingIfNeeded(settings: AppSettings) async -> Bool {
        guard UIApplication.shared.applicationState == .active else { return false }
        guard settings.hasCompletedIntroduction else { return false }

        if #available(iOS 14, *) {
            let status = ATTrackingManager.trackingAuthorizationStatus
            guard status == .notDetermined, !settings.hasRequestedTrackingPermission else {
                settings.hasRequestedTrackingPermission = true
                return false
            }

            let updatedStatus = await ATTrackingManager.requestTrackingAuthorization()
            settings.hasRequestedTrackingPermission = true
            return updatedStatus != .notDetermined
        } else {
            settings.hasRequestedTrackingPermission = true
            return false
        }
    }

    func startMobileAdsIfNeeded() {
        guard !hasStartedMobileAds else { return }
        MobileAds.shared.start()
        hasStartedMobileAds = true
    }
}
