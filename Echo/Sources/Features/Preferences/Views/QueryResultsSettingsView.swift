import SwiftUI
import EchoSense

struct QueryResultsSettingsView: View {
    @Environment(ProjectStore.self) internal var projectStore
    @EnvironmentObject internal var appearanceStore: AppearanceStore

    @State internal var selectedEngineTab: EngineTab = .postgres

    internal enum EngineTab: Hashable { case postgres, sqlserver, mysql, sqlite }

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
                        .padding(.top, SpacingTokens.xxxs)
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
                .padding(.top, SpacingTokens.xxs2)
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

}
