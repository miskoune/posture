import Foundation
import PostureCore
import UserNotifications

/// The banner, with the system's default chime.
///
/// No badge. Deciding when to speak — and when to repeat — belongs to
/// `SlouchTracker`, so this type only ever does what it is told.
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
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
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
        content.sound = .default

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

    /// The tone escalates with the duration — a nudge at first, a firmer push
    /// once the slouch has clearly settled in — and each tier rotates a few
    /// phrasings so repeat reminders don't read as a stuck record.
    private func body(forMinutes minutes: Int) -> String {
        let duration = minutes <= 1 ? "a minute" : "\(minutes) minutes"
        return lines(forMinutes: minutes, duration: duration).randomElement()
            ?? "Bad posture. Sit back."
    }

    private func lines(forMinutes minutes: Int, duration: String) -> [String] {
        switch minutes {
        case ..<5:
            return [
                "Bad posture for \(duration). Sit back.",
                "Bad posture for \(duration). Straighten up.",
                "Bad posture for \(duration). Shoulders back."
            ]
        case ..<15:
            return [
                "Still bad posture — \(duration) now. Sit up.",
                "Bad posture for \(duration). Time to sit back.",
                "\(duration.capitalized) of bad posture. Reset your position."
            ]
        default:
            return [
                "Bad posture for \(duration). Stand up and stretch.",
                "\(duration.capitalized) of bad posture. Your back needs a break.",
                "Bad posture for \(duration). Walk around for a moment."
            ]
        }
    }
}
