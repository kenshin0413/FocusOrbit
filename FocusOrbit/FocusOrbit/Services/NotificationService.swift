import Foundation
import UserNotifications

actor NotificationService {
    static let shared = NotificationService()
    func requestAuthorization() async { _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) }
    func scheduleCompletion(missionID: UUID, destinationName: String, endDate: Date) async {
        let content = UNMutableNotificationContent()
        content.title = LocalizedRuntime.text(ja: "目的地へ到着しました", en: "You have arrived")
        content.body = LocalizedRuntime.text(ja: "\(destinationName)への航行が完了しました。", en: "Your flight to \(destinationName) has been completed.")
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(endDate.timeIntervalSinceNow, 1), repeats: false)
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: missionID.uuidString, content: content, trigger: trigger))
    }
    nonisolated func cancel(missionID: UUID) { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [missionID.uuidString]) }
}
