/// What the user asked for, from whichever surface they used: the menu bar
/// or the dashboard. `AppDelegate` decides what each command means, so every
/// surface stays presentation-only.
enum AppCommand {
    case calibrate
    case showDashboard
    case togglePause
    case setTolerance(Double)
    case setPatience(Double)
    case setNudgeRepeat(Double)
    case togglePreviewOnNudge
}
