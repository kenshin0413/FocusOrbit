import Foundation
@preconcurrency import GoogleMobileAds
import UIKit

@MainActor
final class AppOpenAdManager: NSObject {
    private static let presentationWindow: TimeInterval = 4
    private static let adExpirationWindow: TimeInterval = 4 * 60 * 60
    private static let minimumPresentationInterval: TimeInterval = 3 * 60 * 60
    private static let lastPresentationDateKey = "app_open_ad_last_presentation_date"

    #if DEBUG
    private static let adUnitID = "ca-app-pub-3940256099942544/5575463023"
    #else
    private static let adUnitID = "ca-app-pub-2277987033120510/9210815189"
    #endif

    private var appOpenAd: AppOpenAd?
    private var isLoadingAd = false
    private var isShowingAd = false
    private var loadTime: Date?
    private var shouldPresentOnLaunch = false
    private var isPrimaryInterfaceReady = false
    private var launchPresentationDeadline: Date?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func prepareLaunchAd() {
        guard canPresentForCurrentLaunch else {
            shouldPresentOnLaunch = false
            return
        }
        shouldPresentOnLaunch = true
        isPrimaryInterfaceReady = false
        launchPresentationDeadline = Date().addingTimeInterval(Self.presentationWindow)
        Task { await loadAdIfNeeded() }
    }

    func markPrimaryInterfaceReady() {
        isPrimaryInterfaceReady = true
        presentIfPossible()
    }

    private func loadAdIfNeeded() async {
        guard !isLoadingAd, !isAdAvailable else { return }
        isLoadingAd = true

        defer { isLoadingAd = false }

        do {
            let ad = try await AppOpenAd.load(with: Self.adUnitID, request: Request())
            ad.fullScreenContentDelegate = self
            appOpenAd = ad
            loadTime = Date()
            presentIfPossible()
        } catch {
            appOpenAd = nil
            loadTime = nil
            print("App open ad failed to load: \(error.localizedDescription)")
        }
    }

    private var isAdAvailable: Bool {
        guard let loadTime else { return false }
        return appOpenAd != nil && Date().timeIntervalSince(loadTime) < Self.adExpirationWindow
    }

    private var canPresentForCurrentLaunch: Bool {
        guard let lastPresentedAt = defaults.object(forKey: Self.lastPresentationDateKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastPresentedAt) >= Self.minimumPresentationInterval
    }

    private var canPresentNow: Bool {
        guard shouldPresentOnLaunch,
              isPrimaryInterfaceReady,
              !isShowingAd,
              UIApplication.shared.applicationState == .active else { return false }
        guard let deadline = launchPresentationDeadline else { return false }
        return Date() <= deadline
    }

    private func presentIfPossible() {
        guard canPresentNow else { return }

        guard isAdAvailable, let appOpenAd else {
            Task { await loadAdIfNeeded() }
            return
        }

        isShowingAd = true
        shouldPresentOnLaunch = false
        defaults.set(Date(), forKey: Self.lastPresentationDateKey)
        appOpenAd.present(from: nil)
    }
}

extension AppOpenAdManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        appOpenAd = nil
        isShowingAd = false
        loadTime = nil
        Task { await loadAdIfNeeded() }
    }

    func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        print("App open ad failed to present: \(error.localizedDescription)")
        appOpenAd = nil
        isShowingAd = false
        loadTime = nil
    }
}
