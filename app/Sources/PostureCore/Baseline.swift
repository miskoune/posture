import Foundation

/// How far a reading has drifted from the calibrated pose, as a fraction of
/// that pose. Positive means worse, so every axis reads the same direction.
public struct Drift: Equatable {
    /// Head has sunk toward the shoulders.
    public let slump: Double
    /// Body has moved toward the screen.
    public let lean: Double
    /// Head has rotated away from the calibrated angle — nodded down or
    /// tilted toward a shoulder.
    public let tilt: Double

    public func exceeds(_ tolerance: Double) -> Bool {
        slump > tolerance || lean > tolerance || tilt > tolerance
    }
}

/// The pose the user chose as correct, captured once during calibration.
public struct Baseline: Codable, Equatable {
    /// Scales head-angle deviation onto the shared tolerance: a right angle
    /// counts as drift 1.0, so Normal tolerance (0.15) forgives ~13° of tilt
    /// and Strict (0.08) about 7°.
    private static let tiltFullScale = Double.pi / 2

    public let uprightness: Double
    public let proximity: Double
    public let pitch: Double
    public let roll: Double

    public init(uprightness: Double, proximity: Double, pitch: Double = 0, roll: Double = 0) {
        self.uprightness = uprightness
        self.proximity = proximity
        self.pitch = pitch
        self.roll = roll
    }

    /// Averages a calibration run. Returns nil for an empty run rather than
    /// inventing a baseline out of no data.
    public init?(averaging readings: [Reading]) {
        guard !readings.isEmpty else { return nil }
        let count = Double(readings.count)
        self.init(
            uprightness: readings.reduce(0) { $0 + $1.uprightness } / count,
            proximity: readings.reduce(0) { $0 + $1.proximity } / count,
            pitch: readings.reduce(0) { $0 + $1.pitch } / count,
            roll: readings.reduce(0) { $0 + $1.roll } / count
        )
    }

    public func drift(from reading: Reading) -> Drift {
        Drift(
            slump: relativeChange(from: uprightness, to: reading.uprightness, worseWhenLower: true),
            lean: relativeChange(from: proximity, to: reading.proximity, worseWhenLower: false),
            tilt: max(abs(reading.pitch - pitch), abs(reading.roll - roll)) / Self.tiltFullScale
        )
    }

    /// Guarded against a near-zero baseline, which would otherwise divide a
    /// small measurement error into an enormous drift.
    private func relativeChange(
        from base: Double,
        to current: Double,
        worseWhenLower: Bool
    ) -> Double {
        let denominator = max(abs(base), 0.0001)
        let delta = worseWhenLower ? base - current : current - base
        return delta / denominator
    }
}
