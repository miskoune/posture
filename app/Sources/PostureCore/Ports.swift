import Foundation

/// What a single look at the camera produced.
///
/// "I could not see you" and "the camera is unavailable" are ordinary outcomes,
/// not exceptions — the app is expected to run through lunch breaks and closed
/// lids — so they are values the caller must handle, never silent nils.
public enum SensorOutcome: Equatable {
    case measured(Reading)
    case noPersonVisible
    case unavailable(reason: String)
}

/// Anything that can measure how the user is sitting.
///
/// Owned by the core and implemented outside it, so the rules never mention
/// AVFoundation or Vision. It is also the seam the tests use.
public protocol PostureSensor: AnyObject {
    /// Takes one measurement. The completion runs on the main queue.
    func sample(completion: @escaping (SensorOutcome) -> Void)

    /// Monitoring has paused; release whatever sampling holds open. A sensor
    /// with nothing to release can ignore this.
    func rest()
}

public extension PostureSensor {
    func rest() {}
}

/// Anything that can tell the user to sit back — and take it back once the
/// complaint no longer applies.
public protocol NudgeDelivering: AnyObject {
    func deliverNudge(secondsSlouching: Int)

    /// The slouch the nudge complained about is over; withdraw it.
    func clearNudges()
}

/// Where preferences and the calibrated baseline live.
public protocol SettingsStoring: AnyObject {
    var baseline: Baseline? { get set }
    var tolerance: Double { get set }
    var patience: TimeInterval { get set }
    /// Seconds between repeat nudges while posture stays bad; 0 means nudge
    /// once per slouch and stay quiet.
    var nudgeRepeat: TimeInterval { get set }
    /// Whether a nudge also brings up the corner camera preview, so the user
    /// can see themselves back into position.
    var showPreviewOnNudge: Bool { get set }
    var sampleInterval: TimeInterval { get set }
    var isPaused: Bool { get set }
}

/// Time, as a dependency. Lets the tracker's timing rules be tested in
/// microseconds instead of minutes.
public protocol Clock {
    var now: Date { get }
}

public struct SystemClock: Clock {
    public init() {}
    public var now: Date { Date() }
}
