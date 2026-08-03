import Foundation

/// What the menu bar is currently showing. One case per thing the app can
/// honestly say about you.
public enum PostureState: Equatable {
    case needsCalibration
    case calibrating(collected: Int, needed: Int)
    case paused
    case cannotSee
    case unavailable(reason: String)
    case upright
    case slouching(since: Date)
}
