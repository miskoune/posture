import Foundation
import PostureCore
import UserNotifications

/// The banner.
///
/// No badge, no sound. Deciding when to speak — and when to repeat — belongs
/// to `SlouchTracker`, so this type only ever does what it is told.
final class NotificationNudger: NudgeDelivering {
    private let center = UNUserNotificationCenter.current()

    /// One fixed identifier: a repeat reminder replaces the banner instead of
    /// stacking a second one, and `clearNudges` knows what to withdraw.
    private static let nudgeIdentifier = "bad-posture"

    /// A refusal is a legitimate answer: the menu bar icon still shows state,
    /// so the app keeps working without notification permission. The outcome
    /// is logged because ad-hoc re-signing can silently lose the grant, and
    /// the log is the only way to tell "denied" from "never asked".
    func requestAuthorization() {
        center.requestAuthorization(options: [.alert]) { granted, error in
            if let error {
                NSLog("Notification authorization failed: %@", error.localizedDescription)
            } else {
                NSLog("Notification authorization %@", granted ? "granted" : "denied")
            }
        }
    }

    func deliverNudge(minutesSlouching: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Posture"
        content.body = body(forMinutes: minutesSlouching)

        center.add(
            UNNotificationRequest(
                identifier: Self.nudgeIdentifier,
                content: content,
                trigger: nil
            )
        )
    }

    /// Takes the banner down — from the screen and from Notification Center —
    /// the moment the posture it complained about is over.
    func clearNudges() {
        center.removeDeliveredNotifications(withIdentifiers: [Self.nudgeIdentifier])
    }

    private func body(forMinutes minutes: Int) -> String {
        minutes <= 1
            ? "Bad posture for a minute. Sit back."
            : "Bad posture for \(minutes) minutes. Sit back."
    }
}
