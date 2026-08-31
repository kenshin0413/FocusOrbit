import Foundation
@preconcurrency import GoogleMobileAds
import UIKit

@MainActor
final class InterstitialAdManager: NSObject {
    private static let interactionThreshold = 5
    private static let interactionCountKey = "interstitial_ad_interaction_count"

    #if DEBUG
    private static let adUnitID = "ca-app-pub-3940256099942544/4411468910"
    #else
    private static let adUnitID = "ca-app-pub-2277987033120510/7071737001"
    #endif

    private var interstitialAd: InterstitialAd?
    private var isLoadingAd = false
    private var isShowingAd = false
    private var pendingAction: (@MainActor () -> Void)?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func preloadIfNeeded() {
        guard !isLoadingAd, interstitialAd == nil else { return }
        isLoadingAd = true

        Task {
            defer { isLoadingAd = false }

            do {
                let ad = try await InterstitialAd.load(with: Self.adUnitID, request: Request())
                ad.fullScreenContentDelegate = self
                interstitialAd = ad
            } catch {
                interstitialAd = nil
                print("Interstitial ad failed to load: \(error.localizedDescription)")
            }
        }
    }

    func handleTrigger(action: @escaping @MainActor () -> Void) {
        let updatedCount = defaults.integer(forKey: Self.interactionCountKey) + 1
        defaults.set(updatedCount, forKey: Self.interactionCountKey)

        guard updatedCount >= Self.interactionThreshold else {
            action()
            return
        }
        guard canPresentNow else {
            action()
            return
        }
        guard let interstitialAd, !isShowingAd else {
            preloadIfNeeded()
            action()
            return
        }

        isShowingAd = true
        pendingAction = action
        defaults.set(0, forKey: Self.interactionCountKey)
        interstitialAd.present(from: nil)
    }

    private var canPresentNow: Bool {
        !isShowingAd && UIApplication.shared.applicationState == .active
    }
}

extension InterstitialAdManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        interstitialAd = nil
        isShowingAd = false
        pendingAction?()
        pendingAction = nil
        preloadIfNeeded()
    }

    func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        print("Interstitial ad failed to present: \(error.localizedDescription)")
        interstitialAd = nil
        isShowingAd = false
        pendingAction?()
        pendingAction = nil
        preloadIfNeeded()
    }
}
