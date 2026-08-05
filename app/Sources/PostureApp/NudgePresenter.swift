import Foundation
import PostureCore

/// Everything the app does when the core says "speak": the notification, and
/// — if the user wants it — the corner camera preview. One fan-out point, so
/// the monitor keeps talking to a single `NudgeDelivering`.
final class NudgePresenter: NudgeDelivering {
    private let notifications: NotificationNudger
    private let preview: NudgePreviewPanelController
    private let settings: SettingsStoring

    init(
        notifications: NotificationNudger,
        preview: NudgePreviewPanelController,
        settings: SettingsStoring
    ) {
        self.notifications = notifications
        self.preview = preview
        self.settings = settings
    }

    func requestAuthorization() {
        notifications.requestAuthorization()
    }

    func deliverNudge(secondsSlouching: Int) {
        notifications.deliverNudge(secondsSlouching: secondsSlouching)
        if settings.showPreviewOnNudge {
            preview.show()
        }
    }

    func clearNudges() {
        notifications.clearNudges()
        preview.hide()
    }
}
