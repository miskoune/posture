import Foundation

/// How far a reading has drifted from the calibrated pose, as a fraction of
/// that pose. Positive means worse, so both axes read the same direction.
public struct Drift: Equatable {
    /// Head has sunk toward the shoulders.
    public let slump: Double
    /// Body has moved toward the screen.
    public let lean: Double

    public func exceeds(_ tolerance: Double) -> Bool {
        slump > tolerance || lean > tolerance
    }
}

/// The pose the user chose as correct, captured once during calibration.
public struct Baseline: Codable, Equatable {
    public let uprightness: Double
    public let proximity: Double

    public init(uprightness: Double, proximity: Double) {
        self.uprightness = uprightness
        self.proximity = proximity
    }

    /// Averages a calibration run. Returns nil for an empty run rather than
    /// inventing a baseline out of no data.
    public init?(averaging readings: [Reading]) {
        guard !readings.isEmpty else { return nil }
        let count = Double(readings.count)
        self.init(
            uprightness: readings.reduce(0) { $0 + $1.uprightness } / count,
            proximity: readings.reduce(0) { $0 + $1.proximity } / count
        )
    }

    public func drift(from reading: Reading) -> Drift {
        Drift(
            slump: relativeChange(from: uprightness, to: reading.uprightness, worseWhenLower: true),
            lean: relativeChange(from: proximity, to: reading.proximity, worseWhenLower: false)
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
