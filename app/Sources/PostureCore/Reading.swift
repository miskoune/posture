import Foundation

/// One measurement of how a person is sitting.
///
/// This is everything that survives a camera frame. No pixels, no image, no
/// identity — two ratios describing a shape, which is why the app can be
/// honest about never storing a photograph.
public struct Reading: Equatable {
    /// Height of the head above the shoulder line, divided by shoulder width.
    ///
    /// Scale invariant: rolling your chair back shrinks both terms equally. It
    /// falls when the head sinks forward and down, which is what a slouch is.
    public let uprightness: Double

    /// Shoulder width in normalised frame units. Grows as you lean toward the
    /// screen. Deliberately *not* scale invariant — that is the signal.
    public let proximity: Double

    public init(uprightness: Double, proximity: Double) {
        self.uprightness = uprightness
        self.proximity = proximity
    }
}
