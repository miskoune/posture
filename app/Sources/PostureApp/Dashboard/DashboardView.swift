import SwiftUI

/// The dashboard shell: a collapsible sidebar on the left with the app
/// identity and one row per page, the selected page on the right, and the
/// standard toolbar toggle to tuck the sidebar away.
struct DashboardView: View {
    @ObservedObject var model: DashboardModel
    let previewView: PreviewView

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .frame(minWidth: 760, minHeight: 480)
    }

    private var sidebar: some View {
        List(selection: $model.selection) {
            header
                .padding(.vertical, 6)

            Section("Monitor") {
                row(.camera)
            }
            Section("Activity") {
                row(.stats)
            }
            Section("Configure") {
                row(.settings)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 280)
    }

    private var header: some View {
        HStack(spacing: 9) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text("Posture")
                    .font(.system(size: 13, weight: .semibold))
                if let version = Bundle.main.object(
                    forInfoDictionaryKey: "CFBundleShortVersionString"
                ) as? String {
                    Text("Version \(version)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .selectionDisabled()
    }

    private func row(_ page: DashboardModel.Page) -> some View {
        Label(page.title, systemImage: page.symbol)
            .tag(page)
    }

    @ViewBuilder
    private var detail: some View {
        switch model.selection ?? .camera {
        case .camera:
            MonitorPage(model: model, previewView: previewView)
        case .stats:
            StatsPage(model: model)
        case .settings:
            SettingsPage(model: model)
        }
    }
}

// MARK: - Camera

/// The live view: camera filling the page, the verdict floating over it, and
/// pause/calibrate within reach in the toolbar.
struct MonitorPage: View {
    @ObservedObject var model: DashboardModel
    let previewView: PreviewView

    var body: some View {
        CameraPreview(view: previewView)
            .background(.black)
            .overlay(alignment: .bottom) {
                statusCard
                    .padding(16)
            }
            .navigationTitle("Camera")
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        model.togglePause()
                    } label: {
                        Label(
                            model.isPaused ? "Resume" : "Pause",
                            systemImage: model.isPaused ? "play.fill" : "pause.fill"
                        )
                    }
                    .help(model.isPaused ? "Resume monitoring" : "Pause monitoring")

                    Button {
                        model.calibrate()
                    } label: {
                        Label("Calibrate", systemImage: "scope")
                    }
                    .help("Sit the way you want to sit, then click")
                }
            }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Circle()
                    .fill(model.statusTone.color)
                    .frame(width: 9, height: 9)
                Text(model.statusTitle)
                    .font(.system(size: 15, weight: .semibold))
            }
            if !model.statusDetail.isEmpty {
                Text(model.statusDetail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Stats

/// This session's totals as cards, with a bar showing the split.
struct StatsPage: View {
    @ObservedObject var model: DashboardModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    statCard(
                        "Good posture",
                        seconds: model.goodSeconds,
                        color: .green,
                        symbol: "checkmark.circle.fill"
                    )
                    statCard(
                        "Bad posture",
                        seconds: model.badSeconds,
                        color: .orange,
                        symbol: "xmark.circle.fill"
                    )
                }
                splitCard
            }
            .padding(20)
        }
        .navigationTitle("Stats")
    }

    private func statCard(
        _ title: String,
        seconds: TimeInterval,
        color: Color,
        symbol: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(color)
            Text(DashboardModel.format(seconds))
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    private var splitCard: some View {
        let total = model.goodSeconds + model.badSeconds
        let goodShare = total > 0 ? model.goodSeconds / total : 0

        return VStack(alignment: .leading, spacing: 10) {
            Text("Session split")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            if total > 0 {
                GeometryReader { proxy in
                    HStack(spacing: 2) {
                        Capsule()
                            .fill(.green)
                            .frame(width: max(4, proxy.size.width * goodShare))
                        Capsule()
                            .fill(.orange)
                    }
                }
                .frame(height: 8)

                Text("\(Int((goodShare * 100).rounded()))% of this session sitting well")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Nothing measured yet this session.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Settings

/// The grouped settings form: each row a title with an explanation under it
/// and its control on the right, the way modern macOS apps lay it out.
struct SettingsPage: View {
    @ObservedObject var model: DashboardModel

    var body: some View {
        Form {
            Section("Detection") {
                choiceRow(
                    "Sensitivity",
                    "How far you can drift from your calibrated posture before it counts as a slouch.",
                    options: SettingsOptions.tolerances,
                    selection: Binding(
                        get: { model.tolerance },
                        set: { model.choose(tolerance: $0) }
                    )
                )

                LabeledContent {
                    Button(model.isCalibrated ? "Recalibrate" : "Calibrate") {
                        model.calibrate()
                    }
                } label: {
                    Text("Calibration")
                    Text(
                        model.isCalibrated
                            ? "Sit the way you want to sit, then recalibrate."
                            : "Not calibrated yet. Sit the way you want to sit, then calibrate."
                    )
                }
            }

            Section("Notifications") {
                choiceRow(
                    "Wait before notifying",
                    "How long bad posture must last before Posture says anything.",
                    options: SettingsOptions.patiences,
                    selection: Binding(
                        get: { model.patience },
                        set: { model.choose(patience: $0) }
                    )
                )

                choiceRow(
                    "Remind again while bad",
                    "How often to repeat the reminder while the slouch continues.",
                    options: SettingsOptions.nudgeRepeats,
                    selection: Binding(
                        get: { model.nudgeRepeat },
                        set: { model.choose(nudgeRepeat: $0) }
                    )
                )

                LabeledContent {
                    Toggle("", isOn: Binding(
                        get: { model.showPreviewOnNudge },
                        set: { model.setShowPreviewOnNudge($0) }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                } label: {
                    Text("Show preview when notified")
                    Text("A nudge also brings up a small camera preview in the corner of your screen.")
                }
            }

            Section("Monitoring") {
                LabeledContent {
                    Toggle("", isOn: Binding(
                        get: { !model.isPaused },
                        set: { _ in model.togglePause() }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                } label: {
                    Text("Watch my posture")
                    Text("Turn off to pause monitoring and notifications.")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }

    private func choiceRow(
        _ title: String,
        _ description: String,
        options: [SettingChoice],
        selection: Binding<Double>
    ) -> some View {
        LabeledContent {
            Picker("", selection: selection) {
                ForEach(options) { option in
                    Text(option.label).tag(option.value)
                }
            }
            .labelsHidden()
            .fixedSize()
        } label: {
            Text(title)
            Text(description)
        }
    }
}
