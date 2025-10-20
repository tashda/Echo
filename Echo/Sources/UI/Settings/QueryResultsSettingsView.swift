import SwiftUI
#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

private let streamingRowPresets: [Int] = [100, 250, 500, 750, 1_000, 2_000, 5_000, 10_000]
private let streamingThresholdPresets: [Int] = [512, 1_000, 2_000, 5_000, 10_000, 20_000, 50_000, 100_000, 250_000, 500_000, 1_000_000]
private let streamingFetchPresets: [Int] = [128, 256, 384, 512, 768, 1_024, 2_048, 4_096, 8_192, 16_384]
private let streamingFetchRampMultiplierPresets: [Int] = [2, 4, 6, 8, 12, 16, 24, 32, 48, 64]
private let streamingFetchRampMaxPresets: [Int] = [32_768, 65_536, 131_072, 262_144, 524_288, 786_432, 1_048_576]

private enum ResultStreamingDefaults {
    static let initialRows = 500
    static let previewBatch = 500
    static let backgroundThreshold = 512
    static let fetchSize = 4_096
    static let fetchRampMultiplier = 24
    static let fetchRampMax = 524_288
    static let useCursor = false
}

struct QueryResultsSettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var themeManager: ThemeManager

    private var displayModeBinding: Binding<ForeignKeyDisplayMode> {
        Binding(
            get: { appModel.globalSettings.foreignKeyDisplayMode },
            set: { newValue in
                guard appModel.globalSettings.foreignKeyDisplayMode != newValue else { return }
                Task { await appModel.updateGlobalEditorDisplay { $0.foreignKeyDisplayMode = newValue } }
            }
        )
    }

    private var inspectorBehaviorBinding: Binding<ForeignKeyInspectorBehavior> {
        Binding(
            get: { appModel.globalSettings.foreignKeyInspectorBehavior },
            set: { newValue in
                guard appModel.globalSettings.foreignKeyInspectorBehavior != newValue else { return }
                Task { await appModel.updateGlobalEditorDisplay { $0.foreignKeyInspectorBehavior = newValue } }
            }
        )
    }

    private var includeRelatedBinding: Binding<Bool> {
        Binding(
            get: { appModel.globalSettings.foreignKeyIncludeRelated },
            set: { newValue in
                guard appModel.globalSettings.foreignKeyIncludeRelated != newValue else { return }
                Task { await appModel.updateGlobalEditorDisplay { $0.foreignKeyIncludeRelated = newValue } }
            }
        )
    }

    private var initialRowLimitBinding: Binding<Int> {
        Binding(
            get: { appModel.globalSettings.resultsInitialRowLimit },
            set: { newValue in
                let clamped = max(100, min(newValue, 100_000))
                guard appModel.globalSettings.resultsInitialRowLimit != clamped else { return }
                Task { await appModel.updateResultsStreaming(initialRowLimit: clamped) }
            }
        )
    }

    private var previewBatchSizeBinding: Binding<Int> {
        Binding(
            get: { appModel.globalSettings.resultsPreviewBatchSize },
            set: { newValue in
                let clamped = max(100, min(newValue, 100_000))
                guard appModel.globalSettings.resultsPreviewBatchSize != clamped else { return }
                Task { await appModel.updateResultsStreaming(previewBatchSize: clamped) }
            }
        )
    }

    private var backgroundStreamingThresholdBinding: Binding<Int> {
        Binding(
            get: { appModel.globalSettings.resultsBackgroundStreamingThreshold },
            set: { newValue in
                let clamped = max(100, min(newValue, 1_000_000))
                guard appModel.globalSettings.resultsBackgroundStreamingThreshold != clamped else { return }
                Task { await appModel.updateResultsStreaming(backgroundStreamingThreshold: clamped) }
            }
        )
    }

    private var backgroundFetchSizeBinding: Binding<Int> {
        Binding(
            get: { appModel.globalSettings.resultsStreamingFetchSize },
            set: { newValue in
                let clamped = max(128, min(newValue, 16_384))
                guard appModel.globalSettings.resultsStreamingFetchSize != clamped else { return }
                Task { await appModel.updateResultsStreaming(backgroundFetchSize: clamped) }
            }
        )
    }

    private var fetchRampMultiplierBinding: Binding<Int> {
        Binding(
            get: { appModel.globalSettings.resultsStreamingFetchRampMultiplier },
            set: { newValue in
                let clamped = max(1, min(newValue, 64))
                guard appModel.globalSettings.resultsStreamingFetchRampMultiplier != clamped else { return }
                Task { await appModel.updateResultsStreaming(backgroundFetchRampMultiplier: clamped) }
            }
        )
    }

    private var fetchRampMaxBinding: Binding<Int> {
        Binding(
            get: { appModel.globalSettings.resultsStreamingFetchRampMax },
            set: { newValue in
                let clamped = max(256, min(newValue, 1_048_576))
                guard appModel.globalSettings.resultsStreamingFetchRampMax != clamped else { return }
                Task { await appModel.updateResultsStreaming(backgroundFetchRampMax: clamped) }
            }
        )
    }

    private var useCursorStreamingBinding: Binding<Bool> {
        Binding(
            get: { appModel.globalSettings.resultsUseCursorStreaming },
            set: { newValue in
                guard appModel.globalSettings.resultsUseCursorStreaming != newValue else { return }
                Task { await appModel.updateResultsStreaming(useCursorStreaming: newValue) }
            }
        )
    }

    private var selectedDisplayMode: ForeignKeyDisplayMode { displayModeBinding.wrappedValue }
    private var selectedBehavior: ForeignKeyInspectorBehavior { inspectorBehaviorBinding.wrappedValue }

    private var streamingSettingsAreDefault: Bool {
        let settings = appModel.globalSettings
        return settings.resultsInitialRowLimit == ResultStreamingDefaults.initialRows &&
        settings.resultsPreviewBatchSize == ResultStreamingDefaults.previewBatch &&
        settings.resultsBackgroundStreamingThreshold == ResultStreamingDefaults.backgroundThreshold &&
        settings.resultsStreamingFetchSize == ResultStreamingDefaults.fetchSize &&
        settings.resultsStreamingFetchRampMultiplier == ResultStreamingDefaults.fetchRampMultiplier &&
        settings.resultsStreamingFetchRampMax == ResultStreamingDefaults.fetchRampMax &&
        settings.resultsUseCursorStreaming == ResultStreamingDefaults.useCursor
    }

    var body: some View {
        Form {
            Section("Foreign Keys") {
                Picker("Foreign key cells", selection: displayModeBinding) {
                    ForEach(ForeignKeyDisplayMode.allCases, id: \.self) { mode in
                        Text(displayName(for: mode)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(displayDescription(for: selectedDisplayMode))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if selectedDisplayMode != .disabled {
                    Picker("Inspector behavior", selection: inspectorBehaviorBinding) {
                        ForEach(ForeignKeyInspectorBehavior.allCases, id: \.self) { behavior in
                            Text(behaviorDisplayName(for: behavior)).tag(behavior)
                        }
                    }
                    .pickerStyle(.inline)

                    Text(behaviorDescription(for: selectedBehavior))
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Toggle("Include related foreign keys", isOn: includeRelatedBinding)
                        .toggleStyle(.switch)

                    Text("When enabled, the inspector also loads rows referenced by the selected record's foreign keys. This can increase query count on large schemas.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }

            Section("Result Streaming") {
                StreamingPresetPickerControl(
                    title: "Initial rows to display",
                    value: initialRowLimitBinding,
                    description: "Controls how many rows render immediately when a query begins streaming results.",
                    presets: streamingRowPresets,
                    range: 100...100_000,
                    formatter: formatRowCount,
                    defaultValue: ResultStreamingDefaults.initialRows
                )

                StreamingPresetPickerControl(
                    title: "Data preview batch size",
                    value: previewBatchSizeBinding,
                    description: "Used when opening table previews from the sidebar. Additional batches keep loading in the background until the table finishes streaming.",
                    presets: streamingRowPresets,
                    range: 100...100_000,
                    formatter: formatRowCount,
                    defaultValue: ResultStreamingDefaults.previewBatch
                )

                StreamingPresetPickerControl(
                    title: "Background streaming threshold",
                    value: backgroundStreamingThresholdBinding,
                    description: "After this many rows are streamed, Echo hands off ingestion to a background worker so the grid stays responsive. Increase the value if you prefer more live rows in memory, decrease it for faster background streaming.",
                    presets: streamingThresholdPresets,
                    range: 100...1_000_000,
                    formatter: formatRowCount,
                    defaultValue: ResultStreamingDefaults.backgroundThreshold
                )

                StreamingPresetPickerControl(
                    title: "Background fetch batch size",
                    value: backgroundFetchSizeBinding,
                    description: "Controls how many rows Echo asks the server for in each background fetch. Smaller batches stream more frequently; larger batches minimize network round-trips but can increase latency before updates appear.",
                    presets: streamingFetchPresets,
                    range: 128...16_384,
                    formatter: formatRowCount,
                    defaultValue: ResultStreamingDefaults.fetchSize
                )

                StreamingPresetPickerControl(
                    title: "Fetch ramp multiplier",
                    value: fetchRampMultiplierBinding,
                    description: "Determines how aggressively Echo expands background fetch sizes once the initial preview is loaded.",
                    presets: streamingFetchRampMultiplierPresets,
                    range: 1...64,
                    formatter: formatMultiplier,
                    defaultValue: ResultStreamingDefaults.fetchRampMultiplier
                )

                StreamingPresetPickerControl(
                    title: "Fetch ramp maximum",
                    value: fetchRampMaxBinding,
                    description: "Caps the largest background fetch Echo will request to help balance latency with memory usage.",
                    presets: streamingFetchRampMaxPresets,
                    range: 256...1_048_576,
                    formatter: formatRowCount,
                    defaultValue: ResultStreamingDefaults.fetchRampMax
                )

                Toggle("Use cursor-based streaming", isOn: useCursorStreamingBinding)
                    .toggleStyle(.switch)
                Text("Keeps the legacy DECLARE/FETCH pipeline active. Disable for the new simple streaming worker.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)

                HStack {
                    Spacer()
                    Button("Revert to Default") {
                        Task {
                            await appModel.updateResultsStreaming(
                                initialRowLimit: ResultStreamingDefaults.initialRows,
                                previewBatchSize: ResultStreamingDefaults.previewBatch,
                                backgroundStreamingThreshold: ResultStreamingDefaults.backgroundThreshold,
                                backgroundFetchSize: ResultStreamingDefaults.fetchSize,
                                backgroundFetchRampMultiplier: ResultStreamingDefaults.fetchRampMultiplier,
                                backgroundFetchRampMax: ResultStreamingDefaults.fetchRampMax,
                                useCursorStreaming: ResultStreamingDefaults.useCursor
                            )
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(streamingSettingsAreDefault)
                }
                .padding(.top, 6)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(themeManager.surfaceBackground)
    }

    private func displayName(for mode: ForeignKeyDisplayMode) -> String {
        switch mode {
        case .showInspector: return "Open in Inspector"
        case .showIcon: return "Show Cell Icon"
        case .disabled: return "Do Nothing"
        }
    }

    private func displayDescription(for mode: ForeignKeyDisplayMode) -> String {
        switch mode {
        case .showInspector:
            return "Selecting a foreign key cell immediately loads the referenced record."
        case .showIcon:
            return "Foreign key cells display an inline action icon so you can open the referenced record on demand."
        case .disabled:
            return "Foreign key metadata is ignored in the results grid."
        }
    }

    private func behaviorDisplayName(for behavior: ForeignKeyInspectorBehavior) -> String {
        switch behavior {
        case .respectInspectorVisibility: return "Use Current Inspector State"
        case .autoOpenAndClose: return "Auto Open & Close"
        }
    }

    private func behaviorDescription(for behavior: ForeignKeyInspectorBehavior) -> String {
        switch behavior {
        case .respectInspectorVisibility:
            return "Only populate the inspector when it is already visible."
        case .autoOpenAndClose:
            return "Automatically open the inspector when a foreign key is activated and close it when the selection moves away."
        }
    }

    private func formatMultiplier(_ value: Int) -> String {
        "\(value)x"
    }

    private func formatRowCount(_ value: Int) -> String {
        value.formatted()
    }
}

private struct StreamingPresetPickerControl: View {
    private enum Selection: Hashable {
        case preset(Int)
        case custom
    }

    let title: String
    @Binding var value: Int
    let description: String
    let presets: [Int]
    let range: ClosedRange<Int>
    let formatter: (Int) -> String
    let defaultValue: Int

    @State private var selection: Selection
    @State private var customText: String
    @State private var showInfoPopover = false
    @State private var showCustomPopover = false
    @State private var pendingCustomPresentation = false

    init(title: String,
         value: Binding<Int>,
         description: String,
         presets: [Int],
         range: ClosedRange<Int>,
         formatter: @escaping (Int) -> String,
         defaultValue: Int) {
        self.title = title
        self._value = value
        self.description = description
        self.presets = presets
        self.range = range
        self.formatter = formatter
        self.defaultValue = defaultValue

        let initialValue = value.wrappedValue
        if presets.contains(initialValue) {
            _selection = State(initialValue: .preset(initialValue))
        } else {
            _selection = State(initialValue: .custom)
        }
        _customText = State(initialValue: String(initialValue))
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)

            Menu {
                ForEach(presets, id: \.self) { preset in
                    Button(action: { selection = .preset(preset) }) {
                        if value == preset {
                            Label(label(for: preset), systemImage: "checkmark")
                        } else {
                            Text(label(for: preset))
                        }
                    }
                }
                Divider()
                Button("Custom…") {
                    pendingCustomPresentation = true
                    selection = .custom
                }
            } label: {
                HStack(spacing: 6) {
                    Text(displayValueLabel)
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .opacity(0.7)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(valueButtonBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .popover(isPresented: $showCustomPopover, arrowEdge: .trailing) {
                CustomValuePopover(
                    title: title,
                    text: $customText,
                    rangeDescription: "\(formatter(range.lowerBound)) – \(formatter(range.upperBound))",
                    onSubmit: applyCustomValue,
                    onCancel: { showCustomPopover = false }
                )
            }

            Button(action: { showInfoPopover.toggle() }) {
                Image(systemName: "info.circle")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .popover(isPresented: $showInfoPopover, arrowEdge: .trailing) {
                InfoPopover(description: description, defaultLabel: defaultLabel)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onChange(of: selection, initial: false) { _, newSelection in
            handleSelectionChange(newSelection)
        }
        .onChange(of: value, initial: false) { _, newValue in
            syncSelection(with: newValue)
        }
        .onChange(of: showCustomPopover) { _, isPresented in
            if !isPresented {
                pendingCustomPresentation = false
            }
        }
    }

    private func handleSelectionChange(_ newSelection: Selection) {
        switch newSelection {
        case .preset(let preset):
            setValue(preset)
            showCustomPopover = false
        case .custom:
            customText = String(value)
            if pendingCustomPresentation {
                showCustomPopover = true
            }
            pendingCustomPresentation = false
        }
    }

    private func syncSelection(with newValue: Int) {
        if presets.contains(newValue) {
            let target = Selection.preset(newValue)
            if selection != target {
                selection = target
            }
            customText = String(newValue)
            return
        }
        if selection != .custom {
            selection = .custom
        }
        customText = String(newValue)
        pendingCustomPresentation = false
    }

    private func applyCustomValue() {
        guard let raw = Int(customText) else {
            customText = String(value)
            return
        }
        setValue(raw)
        showCustomPopover = false
    }

    private func setValue(_ newValue: Int) {
        let clamped = clamp(newValue)
        value = clamped
        customText = String(clamped)
    }

    private func clamp(_ candidate: Int) -> Int {
        min(max(candidate, range.lowerBound), range.upperBound)
    }

    private func label(for preset: Int) -> String {
        let base = formatter(preset)
        return preset == defaultValue ? "\(base) (Default)" : base
    }

    private var displayValueLabel: String {
        let base = formatter(value)
        return value == defaultValue ? "\(base) (Default)" : base
    }

    private var defaultLabel: String {
        formatter(defaultValue)
    }

    private var valueButtonBackground: some View {
#if os(macOS)
        Color(nsColor: .controlBackgroundColor).opacity(0.65)
#else
        Color(uiColor: .secondarySystemBackground)
#endif
    }

    private var rowBackground: some View {
#if os(macOS)
        Color(nsColor: .controlBackgroundColor).opacity(0.35)
#else
        Color(uiColor: .systemBackground).opacity(0.8)
#endif
    }

    private struct CustomValuePopover: View {
        let title: String
        @Binding var text: String
        let rangeDescription: String
        let onSubmit: () -> Void
        let onCancel: () -> Void
        @FocusState private var fieldFocused: Bool

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Custom \(title)")
                    .font(.headline)

                TextField("Value", text: $text)
                    .textFieldStyle(.roundedBorder)
#if os(iOS)
                    .keyboardType(.numberPad)
#endif
                    .focused($fieldFocused)

                Text("Allowed range: \(rangeDescription)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Spacer()
                    Button("Cancel", role: .cancel, action: onCancel)
                    Button("Done", action: onSubmit)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(16)
            .frame(width: 260)
            .background(VisualEffectBlur.swiftUI)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(4)
            .onAppear {
                DispatchQueue.main.async {
                    fieldFocused = true
                }
            }
        }
    }

    private struct InfoPopover: View {
        let description: String
        let defaultLabel: String

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(description)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                Text("Default: \(defaultLabel)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: 320)
            .background(VisualEffectBlur.swiftUI)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(4)
        }
    }
}

#if os(macOS)
private struct VisualEffectBlur: NSViewRepresentable {
    static var swiftUI: some View { VisualEffectBlur(material: .underWindowBackground, blendingMode: .withinWindow) }

    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
    }
}
#else
private struct VisualEffectBlur: UIViewRepresentable {
    static var swiftUI: some View { VisualEffectBlur(style: .systemMaterial) }

    var style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}
#endif
