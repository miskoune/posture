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

    public init(uprightness: Double, proximity: Double) {
        self.uprightness = uprightness
        self.proximity = proximity
    }
}
