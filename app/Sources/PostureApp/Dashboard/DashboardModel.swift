import SwiftUI
import PostureCore

/// Everything the SwiftUI dashboard renders, mirrored from `SettingsStoring`
/// and `PostureMonitor` by the window controller once a second and on every
/// detection. Mutations go out through `onCommand`, reusing the menu's
/// vocabulary so `AppDelegate` handles both sources identically; nothing here
/// writes settings directly.
final class DashboardModel: ObservableObject {
    enum Page: String, CaseIterable, Identifiable {
        case camera
        case stats
        case settings

        var id: String { rawValue }

        var title: String {
            switch self {
            case .camera: return "Camera"
            case .stats: return "Stats"
            case .settings: return "Settings"
            }
        }

        var symbol: String {
            switch self {
            case .camera: return "video"
            case .stats: return "chart.bar"
            case .settings: return "gearshape"
            }
        }
    }

    /// The verdict's color family, kept abstract so AppKit (face box) and
    /// SwiftUI (status card) can each map it to their own color type.
    enum Tone {
        case good
        case bad
        case neutral

        var color: Color {
            switch self {
            case .good: return .green
            case .bad: return .orange
            case .neutral: return .secondary
            }
        }
    }

    @Published var selection: Page? = .camera

    @Published var statusTitle = "Starting camera…"
    @Published var statusDetail = ""
    @Published var statusTone = Tone.neutral

    @Published var goodSeconds: TimeInterval = 0
    @Published var badSeconds: TimeInterval = 0

    @Published var isPaused = false
    @Published var isCalibrated = false
    @Published var tolerance = UserDefaultsSettings.defaultTolerance
    @Published var patience = UserDefaultsSettings.defaultPatience
    @Published var nudgeRepeat = UserDefaultsSettings.defaultNudgeRepeat
    @Published var showPreviewOnNudge = true

    var onCommand: ((StatusMenuController.Command) -> Void)?

    // MARK: - Intents

    /// Optimistic: the published value flips right away so the control feels
    /// instant, and the next sync from the controller confirms it.

    func choose(tolerance value: Double) {
        guard value != tolerance else { return }
        tolerance = value
        onCommand?(.setTolerance(value))
    }

    func choose(patience value: Double) {
        guard value != patience else { return }
        patience = value
        onCommand?(.setPatience(value))
    }

    func choose(nudgeRepeat value: Double) {
        guard value != nudgeRepeat else { return }
        nudgeRepeat = value
        onCommand?(.setNudgeRepeat(value))
    }

    func setShowPreviewOnNudge(_ value: Bool) {
        guard value != showPreviewOnNudge else { return }
        showPreviewOnNudge = value
        onCommand?(.togglePreviewOnNudge)
    }

    func togglePause() {
        isPaused.toggle()
        onCommand?(.togglePause)
    }

    /// Jumps to the camera page so the calibration countdown is visible.
    func calibrate() {
        selection = .camera
        onCommand?(.calibrate)
    }

    // MARK: - Formatting

    static func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m \(total % 60)s" }
        return "\(total)s"
    }
}
