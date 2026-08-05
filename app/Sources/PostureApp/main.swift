import AppKit
import PostureCore

// The composition root: the one place allowed to name concrete types. Every
// other file in the app depends on a protocol from PostureCore, which is what
// keeps the camera swappable and the rules testable.

// NSApplication comes first. Anything that touches AppKit's shared state — the
// status bar in particular — must not run before it exists.
let app = NSApplication.shared

let settings = UserDefaultsSettings()
let sensor = CameraSensor()
let nudger = NudgePresenter(
    notifications: NotificationNudger(),
    preview: NudgePreviewPanelController(settings: settings),
    settings: settings
)

let monitor = PostureMonitor(
    sensor: sensor,
    nudger: nudger,
    settings: settings
)

let delegate = AppDelegate(
    settings: settings,
    monitor: monitor,
    nudger: nudger
)

app.delegate = delegate
// .accessory keeps it out of the Dock and the app switcher: a menu bar app.
app.setActivationPolicy(.accessory)
app.run()
