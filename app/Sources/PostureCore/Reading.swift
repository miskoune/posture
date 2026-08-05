import Foundation

/// One measurement of how a person is sitting.
///
/// This is everything that survives a camera frame. No pixels, no image, no
/// identity — two ratios describing a shape, which is why the app can be
/// honest about never storing a photograph.
public struct Reading: Equatable {
    /// How high the head sits in the frame, 0 at the bottom edge, 1 at the
    /// top. It falls when the head sinks forward and down, which is what a
    /// slouch is. Assumes the camera does not move — a laptop lid.
    public let uprightness: Double

    /// Apparent head width as a fraction of the frame. Grows as you lean
    /// toward the screen — that is the signal.
    public let proximity: Double

    /// Head pitch in radians — nodding forward and down, the slouch the face
    /// box cannot see because the head barely moves in the frame. Only the
    /// deviation from the calibrated value matters, so the sign convention of
    /// whoever measured it is irrelevant.
    public let pitch: Double

    /// Head roll in radians — tilting toward a shoulder.
    public let roll: Double

    public init(uprightness: Double, proximity: Double, pitch: Double = 0, roll: Double = 0) {
        self.uprightness = uprightness
        self.proximity = proximity
        self.pitch = pitch
        self.roll = roll
    }
}
