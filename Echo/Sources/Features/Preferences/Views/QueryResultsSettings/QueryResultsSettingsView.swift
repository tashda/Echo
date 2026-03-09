import SwiftUI
import EchoSense

struct QueryResultsSettingsView: View {
    @Environment(ProjectStore.self) internal var projectStore
    @EnvironmentObject internal var appearanceStore: AppearanceStore

    @State internal var selectedEngineTab: EngineTab = .postgres

    internal enum EngineTab: Hashable { case postgres, sqlserver, mysql, sqlite }

    var body: some View {
        ScrollViewReader { proxy in
        Form {
            Section("Appearance") {
                SettingsRowWithInfo(
                    title: "Alternate row shading",
                    description: "Applies alternating background colors to result table rows for easier reading."
                ) {
                    Toggle("", isOn: alternateRowShadingBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            Section("Foreign Key Cells") {
                SettingsRowWithInfo(
                    title: "Cell Behaviour",
                    description: displayDescription(for: selectedDisplayMode)
                ) {
                    Picker("", selection: displayModeBinding) {
                        ForEach(ForeignKeyDisplayMode.allCases, id: \.self) { mode in
                            Text(displayName(for: mode)).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }

                if selectedDisplayMode == .showInspector {
                    SettingsRowWithInfo(
                        title: "Inspector Behaviour",
                        description: behaviorDescription(for: selectedBehavior)
                    ) {
                        Picker("", selection: inspectorBehaviorBinding) {
                            ForEach(ForeignKeyInspectorBehavior.allCases, id: \.self) { behavior in
                                Text(behaviorDisplayName(for: behavior)).tag(behavior)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }

                    SettingsRowWithInfo(
                        title: "Include related foreign keys",
                        description: "When enabled, the inspector also loads rows referenced by the selected record's foreign keys."
                    ) {
                        Toggle("", isOn: includeRelatedBinding)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }
            }

            Section("Inspector") {
                SettingsRowWithInfo(
                    title: "Auto-open on selection",
                    description: "Automatically opens the inspector panel when selecting items like job history rows."
                ) {
                    Toggle("", isOn: autoOpenInspectorBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
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
                    title: "Data Preview Batch Size",
                    value: previewBatchSizeBinding,
                    description: "Used when opening table previews from the sidebar.",
                    presets: streamingRowPresets,
                    range: 100...100_000,
                    formatter: formatRowCount,
                    defaultValue: ResultStreamingDefaults.previewBatch
                )

                StreamingPresetPickerControl(
                    title: "Background Streaming Threshold",
                    value: backgroundStreamingThresholdBinding,
                    description: "After this many rows are streamed, Echo hands off ingestion to a background worker.",
                    presets: streamingThresholdPresets,
                    range: 100...1_000_000,
                    formatter: formatRowCount,
                    defaultValue: ResultStreamingDefaults.backgroundThreshold
                )

                StreamingPresetPickerControl(
                    title: "Background Fetch Batch Size",
                    value: backgroundFetchSizeBinding,
                    description: "Controls how many rows Echo asks the server for in each background fetch.",
                    presets: streamingFetchPresets,
                    range: 128...16_384,
                    formatter: formatRowCount,
                    defaultValue: ResultStreamingDefaults.fetchSize
                )

                StreamingPresetPickerControl(
                    title: "Fetch Ramp Multiplier",
                    value: fetchRampMultiplierBinding,
                    description: "Determines how aggressively Echo expands background fetch sizes.",
                    presets: streamingFetchRampMultiplierPresets,
                    range: 1...64,
                    formatter: formatMultiplier,
                    defaultValue: ResultStreamingDefaults.fetchRampMultiplier
                )

                StreamingPresetPickerControl(
                    title: "Fetch Ramp Maximum",
                    value: fetchRampMaxBinding,
                    description: "Caps the largest background fetch Echo will request.",
                    presets: streamingFetchRampMaxPresets,
                    range: 256...1_048_576,
                    formatter: formatRowCount,
                    defaultValue: ResultStreamingDefaults.fetchRampMax
                )

                HStack {
                    Spacer()
                    Button("Revert to Default") {
                        var settings = projectStore.globalSettings
                        settings.resultsInitialRowLimit = ResultStreamingDefaults.initialRows
                        settings.resultsPreviewBatchSize = ResultStreamingDefaults.previewBatch
                        settings.resultsBackgroundStreamingThreshold = ResultStreamingDefaults.backgroundThreshold
                        settings.resultsStreamingFetchSize = ResultStreamingDefaults.fetchSize
                        settings.resultsStreamingFetchRampMultiplier = ResultStreamingDefaults.fetchRampMultiplier
                        settings.resultsStreamingFetchRampMax = ResultStreamingDefaults.fetchRampMax
                        settings.resultsUseCursorStreaming = ResultStreamingDefaults.useCursor
                        settings.resultsCursorStreamingLimitThreshold = ResultStreamingDefaults.cursorLimitThreshold
                        Task { try? await projectStore.updateGlobalSettings(settings) }
                    }
                    .buttonStyle(.bordered)
                    .disabled(streamingSettingsAreDefault)
                }
                .padding(.top, SpacingTokens.xxs2)
            }

            Section("Engine Profiles") {
                Picker("", selection: $selectedEngineTab) {
                    Text("PostgreSQL").tag(EngineTab.postgres)
                    Text("SQL Server").tag(EngineTab.sqlserver)
                    Text("MySQL").tag(EngineTab.mysql)
                    Text("SQLite").tag(EngineTab.sqlite)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)

                engineSpecificSettings
                    .id("engineContent")
            }
            .id("engineProfiles")
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onChange(of: selectedEngineTab) { _, _ in
            withAnimation {
                proxy.scrollTo("engineProfiles", anchor: UnitPoint(x: 0.5, y: 0.85))
            }
        }
        } // ScrollViewReader
    }

}
