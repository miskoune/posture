import Foundation
import PostureCore

/// Preferences and the calibrated baseline, kept in UserDefaults.
///
/// The whole persistence layer. No database, no config file to find, and
/// nothing that leaves the machine.
final class UserDefaultsSettings: SettingsStoring {
    private enum Key {
        static let baseline = "baseline"
        static let tolerance = "tolerance"
        static let patience = "patience"
        static let nudgeRepeat = "nudgeRepeat"
        static let sampleInterval = "sampleInterval"
        static let paused = "paused"
    }

    /// Defaults live here rather than scattered through the code that reads
    /// them, so there is one place to answer "how strict is it out of the box?"
    static let defaultTolerance = 0.15
    static let defaultPatience: TimeInterval = 60
    static let defaultNudgeRepeat: TimeInterval = 300
    static let defaultSampleInterval: TimeInterval = 5

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.tolerance: Self.defaultTolerance,
            Key.patience: Self.defaultPatience,
            Key.nudgeRepeat: Self.defaultNudgeRepeat,
            Key.sampleInterval: Self.defaultSampleInterval,
            Key.paused: false
        ])
    }

    var baseline: Baseline? {
        get {
            guard let data = defaults.data(forKey: Key.baseline) else { return nil }
            return try? JSONDecoder().decode(Baseline.self, from: data)
        }
        set {
            guard let newValue, let data = try? JSONEncoder().encode(newValue) else {
                defaults.removeObject(forKey: Key.baseline)
                return
            }
            defaults.set(data, forKey: Key.baseline)
        }
    }

    /// How far you may drift before it counts as a slouch, as a fraction of
    /// the baseline. 0.15 means 15% worse than calibrated.
    var tolerance: Double {
        get { defaults.double(forKey: Key.tolerance) }
        set { defaults.set(newValue, forKey: Key.tolerance) }
    }

    /// How long a slouch must last before it says anything, in seconds.
    var patience: TimeInterval {
        get { defaults.double(forKey: Key.patience) }
        set { defaults.set(newValue, forKey: Key.patience) }
    }

    /// Seconds between repeat nudges while the slouch continues; 0 means once.
    var nudgeRepeat: TimeInterval {
        get { defaults.double(forKey: Key.nudgeRepeat) }
        set { defaults.set(newValue, forKey: Key.nudgeRepeat) }
    }

    /// Seconds between camera samples.
    var sampleInterval: TimeInterval {
        get { defaults.double(forKey: Key.sampleInterval) }
        set { defaults.set(newValue, forKey: Key.sampleInterval) }
    }

    var isPaused: Bool {
        get { defaults.bool(forKey: Key.paused) }
        set { defaults.set(newValue, forKey: Key.paused) }
    }
}
