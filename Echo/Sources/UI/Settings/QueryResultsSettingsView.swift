import SwiftUI
import EchoSense

struct QueryResultsSettingsView: View {
    @Environment(ProjectStore.self) private var projectStore
    @EnvironmentObject private var themeManager: ThemeManager

    private var displayModeBinding: Binding<ForeignKeyDisplayMode> {
        Binding(
            get: { projectStore.globalSettings.foreignKeyDisplayMode },
            set: { newValue in
                guard projectStore.globalSettings.foreignKeyDisplayMode != newValue else { return }
                var settings = projectStore.globalSettings
                settings.foreignKeyDisplayMode = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    private var inspectorBehaviorBinding: Binding<ForeignKeyInspectorBehavior> {
        Binding(
            get: { projectStore.globalSettings.foreignKeyInspectorBehavior },
            set: { newValue in
                guard projectStore.globalSettings.foreignKeyInspectorBehavior != newValue else { return }
                var settings = projectStore.globalSettings
                settings.foreignKeyInspectorBehavior = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    private var includeRelatedBinding: Binding<Bool> {
        Binding(
            get: { projectStore.globalSettings.foreignKeyIncludeRelated },
            set: { newValue in
                guard projectStore.globalSettings.foreignKeyIncludeRelated != newValue else { return }
                var settings = projectStore.globalSettings
                settings.foreignKeyIncludeRelated = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    private var initialRowLimitBinding: Binding<Int> {
        Binding(
            get: { projectStore.globalSettings.resultsInitialRowLimit },
            set: { newValue in
                let clamped = max(100, min(newValue, 100_000))
                guard projectStore.globalSettings.resultsInitialRowLimit != clamped else { return }
                var settings = projectStore.globalSettings
                settings.resultsInitialRowLimit = clamped
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    private var previewBatchSizeBinding: Binding<Int> {
        Binding(
            get: { projectStore.globalSettings.resultsPreviewBatchSize },
            set: { newValue in
                let clamped = max(100, min(newValue, 100_000))
                guard projectStore.globalSettings.resultsPreviewBatchSize != clamped else { return }
                var settings = projectStore.globalSettings
                settings.resultsPreviewBatchSize = clamped
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    private var backgroundStreamingThresholdBinding: Binding<Int> {
        Binding(
            get: { projectStore.globalSettings.resultsBackgroundStreamingThreshold },
            set: { newValue in
                let clamped = max(100, min(newValue, 1_000_000))
                guard projectStore.globalSettings.resultsBackgroundStreamingThreshold != clamped else { return }
                var settings = projectStore.globalSettings
                settings.resultsBackgroundStreamingThreshold = clamped
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    private var backgroundFetchSizeBinding: Binding<Int> {
        Binding(
            get: { projectStore.globalSettings.resultsStreamingFetchSize },
            set: { newValue in
                let clamped = max(128, min(newValue, 16_384))
                guard projectStore.globalSettings.resultsStreamingFetchSize != clamped else { return }
                var settings = projectStore.globalSettings
                settings.resultsStreamingFetchSize = clamped
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    private var streamingModeBinding: Binding<ResultStreamingExecutionMode> {
        Binding(
            get: { projectStore.globalSettings.resultsStreamingMode },
            set: { newValue in
                guard projectStore.globalSettings.resultsStreamingMode != newValue else { return }
                var settings = projectStore.globalSettings
                settings.resultsStreamingMode = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    private var fetchRampMultiplierBinding: Binding<Int> {
        Binding(
            get: { projectStore.globalSettings.resultsStreamingFetchRampMultiplier },
            set: { newValue in
                let clamped = max(1, min(newValue, 64))
                guard projectStore.globalSettings.resultsStreamingFetchRampMultiplier != clamped else { return }
                var settings = projectStore.globalSettings
                settings.resultsStreamingFetchRampMultiplier = clamped
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    private var fetchRampMaxBinding: Binding<Int> {
        Binding(
            get: { projectStore.globalSettings.resultsStreamingFetchRampMax },
            set: { newValue in
                let clamped = max(256, min(newValue, 1_048_576))
                guard projectStore.globalSettings.resultsStreamingFetchRampMax != clamped else { return }
                var settings = projectStore.globalSettings
                settings.resultsStreamingFetchRampMax = clamped
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    private var mssqlModeBinding: Binding<ResultStreamingExecutionMode> {
        Binding(
            get: { projectStore.globalSettings.mssqlStreamingMode },
            set: { newValue in
                guard projectStore.globalSettings.mssqlStreamingMode != newValue else { return }
                var settings = projectStore.globalSettings
                settings.mssqlStreamingMode = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    private var mysqlModeBinding: Binding<ResultStreamingExecutionMode> {
        Binding(
            get: { projectStore.globalSettings.mysqlStreamingMode },
            set: { newValue in
                guard projectStore.globalSettings.mysqlStreamingMode != newValue else { return }
                var settings = projectStore.globalSettings
                settings.mysqlStreamingMode = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    private var sqliteModeBinding: Binding<ResultStreamingExecutionMode> {
        Binding(
            get: { projectStore.globalSettings.sqliteStreamingMode },
            set: { newValue in
                guard projectStore.globalSettings.sqliteStreamingMode != newValue else { return }
                var settings = projectStore.globalSettings
                settings.sqliteStreamingMode = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    @State private var selectedEngineTab: EngineTab = .postgres

    private enum EngineTab: Hashable { case postgres, sqlserver, mysql, sqlite }

    private var cursorLimitThresholdBinding: Binding<Int> {
        Binding(
            get: { projectStore.globalSettings.resultsCursorStreamingLimitThreshold },
            set: { newValue in
                let clamped = max(0, min(newValue, 100_000))
                guard projectStore.globalSettings.resultsCursorStreamingLimitThreshold != clamped else { return }
                var settings = projectStore.globalSettings
                settings.resultsCursorStreamingLimitThreshold = clamped
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    private var selectedDisplayMode: ForeignKeyDisplayMode { displayModeBinding.wrappedValue }
    private var selectedBehavior: ForeignKeyInspectorBehavior { inspectorBehaviorBinding.wrappedValue }

    private var streamingSettingsAreDefault: Bool {
        let settings = projectStore.globalSettings
        return settings.resultsInitialRowLimit == ResultStreamingDefaults.initialRows &&
        settings.resultsPreviewBatchSize == ResultStreamingDefaults.previewBatch &&
        settings.resultsBackgroundStreamingThreshold == ResultStreamingDefaults.backgroundThreshold &&
        settings.resultsStreamingFetchSize == ResultStreamingDefaults.fetchSize &&
        settings.resultsStreamingFetchRampMultiplier == ResultStreamingDefaults.fetchRampMultiplier &&
        settings.resultsStreamingFetchRampMax == ResultStreamingDefaults.fetchRampMax &&
        settings.resultsUseCursorStreaming == ResultStreamingDefaults.useCursor &&
        settings.resultsCursorStreamingLimitThreshold == ResultStreamingDefaults.cursorLimitThreshold
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

                    Text("When enabled, the inspector also loads rows referenced by the selected record's foreign keys.")
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
                    description: "Used when opening table previews from the sidebar.",
                    presets: streamingRowPresets,
                    range: 100...100_000,
                    formatter: formatRowCount,
                    defaultValue: ResultStreamingDefaults.previewBatch
                )

                StreamingPresetPickerControl(
                    title: "Background streaming threshold",
                    value: backgroundStreamingThresholdBinding,
                    description: "After this many rows are streamed, Echo hands off ingestion to a background worker.",
                    presets: streamingThresholdPresets,
                    range: 100...1_000_000,
                    formatter: formatRowCount,
                    defaultValue: ResultStreamingDefaults.backgroundThreshold
                )

                StreamingPresetPickerControl(
                    title: "Background fetch batch size",
                    value: backgroundFetchSizeBinding,
                    description: "Controls how many rows Echo asks the server for in each background fetch.",
                    presets: streamingFetchPresets,
                    range: 128...16_384,
                    formatter: formatRowCount,
                    defaultValue: ResultStreamingDefaults.fetchSize
                )

                StreamingPresetPickerControl(
                    title: "Fetch ramp multiplier",
                    value: fetchRampMultiplierBinding,
                    description: "Determines how aggressively Echo expands background fetch sizes.",
                    presets: streamingFetchRampMultiplierPresets,
                    range: 1...64,
                    formatter: formatMultiplier,
                    defaultValue: ResultStreamingDefaults.fetchRampMultiplier
                )

                StreamingPresetPickerControl(
                    title: "Fetch ramp maximum",
                    value: fetchRampMaxBinding,
                    description: "Caps the largest background fetch Echo will request.",
                    presets: streamingFetchRampMaxPresets,
                    range: 256...1_048_576,
                    formatter: formatRowCount,
                    defaultValue: ResultStreamingDefaults.fetchRampMax
                )

                Picker("Streaming mode", selection: streamingModeBinding) {
                    ForEach(ResultStreamingExecutionMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Spacer()
                    Button("Revert to Default") {
                        let settings = GlobalSettings()
                        Task { try? await projectStore.updateGlobalSettings(settings) }
                    }
                    .buttonStyle(.bordered)
                    .disabled(streamingSettingsAreDefault)
                }
                .padding(.top, 6)
            }
            
            Section("Engine Profiles") {
                HStack {
                    Spacer(minLength: 0)
                    Picker("", selection: $selectedEngineTab) {
                        Text("PostgreSQL").tag(EngineTab.postgres)
                        Text("SQL Server").tag(EngineTab.sqlserver)
                        Text("MySQL").tag(EngineTab.mysql)
                        Text("SQLite").tag(EngineTab.sqlite)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 520)
                    Spacer(minLength: 0)
                }

                engineSpecificSettings
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var engineSpecificSettings: some View {
        switch selectedEngineTab {
        case .postgres:
            StreamingPresetPickerControl(
                title: "Cursor threshold (LIMIT)",
                value: cursorLimitThresholdBinding,
                description: "LIMIT ≤ threshold → simple streaming; larger/no LIMIT → server‑side cursor.",
                presets: streamingThresholdPresets,
                range: 0...1_000_000,
                formatter: formatRowCount,
                defaultValue: ResultStreamingDefaults.cursorLimitThreshold
            )
            StreamingPresetPickerControl(
                title: "Cursor fetch size (baseline)",
                value: backgroundFetchSizeBinding,
                description: "Recommended ≥ 4,096 for large results.",
                presets: streamingFetchPresets,
                range: 128...16_384,
                formatter: formatRowCount,
                defaultValue: ResultStreamingDefaults.fetchSize
            )
            Text("These options apply to PostgreSQL only.")
                .font(.footnote)
                .foregroundStyle(.secondary)

        case .sqlserver:
            LabeledContent("Streaming mode (SQL Server)") {
                Picker("", selection: mssqlModeBinding) {
                    ForEach(ResultStreamingExecutionMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
            }
            Text("SQL Server uses SELECT TOP/FETCH NEXT; LIMIT threshold does not apply.")
                .font(.footnote)
                .foregroundStyle(.secondary)

        case .mysql:
            LabeledContent("Streaming mode (MySQL)") {
                Picker("", selection: mysqlModeBinding) {
                    ForEach(ResultStreamingExecutionMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
            }
            Text("MySQL streams results without explicit cursors.")
                .font(.footnote)
                .foregroundStyle(.secondary)

        case .sqlite:
            LabeledContent("Streaming mode (SQLite)") {
                Picker("", selection: sqliteModeBinding) {
                    ForEach(ResultStreamingExecutionMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
            }
            Text("SQLite is in‑process; streaming/cursors don't apply.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
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
        case .showInspector: return "Selecting a foreign key cell immediately loads the referenced record."
        case .showIcon: return "Foreign key cells display an inline action icon."
        case .disabled: return "Foreign key metadata is ignored."
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
        case .respectInspectorVisibility: return "Only populate the inspector when it is already visible."
        case .autoOpenAndClose: return "Automatically open/close the inspector based on selection."
        }
    }

    private func formatMultiplier(_ value: Int) -> String { "\(value)x" }
    private func formatRowCount(_ value: Int) -> String { value.formatted() }
}
