import Foundation

/// A calibration run in progress.
///
/// Averaging several readings means one unlucky frame — a yawn, a reach for the
/// coffee — cannot become the pose you are judged against for the rest of the
/// day. Frames Vision could not read are simply not collected, so a run in a
/// dark room takes longer rather than producing a worse baseline.
public struct Calibration: Equatable {
    public let samplesNeeded: Int
    private var samples: [Reading] = []

    public init(samplesNeeded: Int = 5) {
        self.samplesNeeded = max(1, samplesNeeded)
    }

    public var collected: Int { samples.count }
    public var isComplete: Bool { samples.count >= samplesNeeded }

    public mutating func collect(_ outcome: SensorOutcome) {
        guard case .measured(let reading) = outcome else { return }
        samples.append(reading)
    }

    /// The averaged pose, once enough readings are in.
    public var baseline: Baseline? {
        guard isComplete else { return nil }
        return Baseline(averaging: samples)
    }
}
