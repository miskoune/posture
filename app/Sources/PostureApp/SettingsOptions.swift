import Foundation

/// One selectable value in a settings choice list.
struct SettingChoice: Hashable, Identifiable {
    let label: String
    let value: Double
    var id: Double { value }
}

/// The choice tables shared by the menu bar and the dashboard, so the two
/// can never drift apart.
enum SettingsOptions {
    static let tolerances: [SettingChoice] = [
        SettingChoice(label: "Relaxed", value: 0.25),
        SettingChoice(label: "Normal", value: 0.15),
        SettingChoice(label: "Strict", value: 0.08)
    ]

    static let patiences: [SettingChoice] = [
        SettingChoice(label: "10 seconds", value: 10),
        SettingChoice(label: "30 seconds", value: 30),
        SettingChoice(label: "1 minute", value: 60),
        SettingChoice(label: "2 minutes", value: 120),
        SettingChoice(label: "5 minutes", value: 300),
        SettingChoice(label: "15 minutes", value: 900)
    ]

    static let nudgeRepeats: [SettingChoice] = [
        SettingChoice(label: "Only once", value: 0),
        SettingChoice(label: "Every 30 seconds", value: 30),
        SettingChoice(label: "Every minute", value: 60),
        SettingChoice(label: "Every 2 minutes", value: 120),
        SettingChoice(label: "Every 5 minutes", value: 300),
        SettingChoice(label: "Every 10 minutes", value: 600)
    ]
}
