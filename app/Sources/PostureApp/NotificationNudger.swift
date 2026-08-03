import Foundation
import PostureCore
import UserNotifications

/// The one banner.
///
/// No badge, no sound, no repeat while you stay folded over. Re-arming belongs
/// to `SlouchTracker`, so this type only ever does what it is told.
final class NotificationNudger: NudgeDelivering {
    private let center = UNUserNotificationCenter.current()

    /// A refusal is a legitimate answer: the menu bar icon still shows state,
    /// so the app keeps working without notification permission.
    func requestAuthorization() {
        center.requestAuthorization(options: [.alert]) { _, _ in }
    }

    func deliverNudge(minutesSlouching: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Posture"
        content.body = body(forMinutes: minutesSlouching)

        center.add(
            UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
        )
    }

    private func body(forMinutes minutes: Int) -> String {
        minutes <= 1
            ? "You have been leaning in for a minute. Sit back."
            : "You have been leaning in for \(minutes) minutes. Sit back."
    }
}
