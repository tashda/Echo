import SwiftUI

struct DatabasesSettingsView: View {
    @Environment(ProjectStore.self) private var projectStore

    @State private var selectedTab: DatabaseSettingsTab = .shared

    private enum DatabaseSettingsTab: Hashable, CaseIterable {
        case shared
        case postgres
        case sqlserver
        case mysql
        case sqlite

        var title: String {
            switch self {
            case .shared: return "Shared"
            case .postgres: return "PostgreSQL"
            case .sqlserver: return "SQL Server"
            case .mysql: return "MySQL"
            case .sqlite: return "SQLite"
            }
        }
    }

    private var settings: GlobalSettings {
        projectStore.globalSettings
    }

    var body: some View {
        Form {
            Section("Engine Scope") {
                Picker("", selection: $selectedTab) {
                    ForEach(DatabaseSettingsTab.allCases, id: \.self) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            switch selectedTab {
            case .shared:
                sharedSettings
            case .postgres:
                postgresSettings
            case .sqlserver:
                sqlServerSettings
            case .mysql:
                mySQLSettings
            case .sqlite:
                sqliteSettings
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var sharedSettings: some View {
        Section("Execution & Ingestion") {
            StreamingPresetPickerControl(
                title: "Initial rows to display",
                value: initialRowLimitBinding,
                description: "Controls how many rows Echo renders immediately before handing off larger work.",
                presets: streamingRowPresets,
                range: 100...100_000,
                formatter: formatRowCount,
                defaultValue: ResultStreamingDefaults.initialRows
            )

            StreamingPresetPickerControl(
                title: "Data Preview Batch Size",
                value: previewBatchSizeBinding,
                description: "Used when opening previews from the sidebar or object browser.",
                presets: streamingRowPresets,
                range: 100...100_000,
                formatter: formatRowCount,
                defaultValue: ResultStreamingDefaults.previewBatch
            )

            StreamingPresetPickerControl(
                title: "Background Streaming Threshold",
                value: backgroundStreamingThresholdBinding,
                description: "After this many rows, Echo moves ingestion work to a background path.",
                presets: streamingThresholdPresets,
                range: 100...1_000_000,
                formatter: formatRowCount,
                defaultValue: ResultStreamingDefaults.backgroundThreshold
            )

            StreamingPresetPickerControl(
                title: "Background Fetch Batch Size",
                value: backgroundFetchSizeBinding,
                description: "Controls how many rows Echo requests in each background fetch.",
                presets: streamingFetchPresets,
                range: 128...16_384,
                formatter: formatRowCount,
                defaultValue: ResultStreamingDefaults.fetchSize
            )

            StreamingPresetPickerControl(
                title: "Fetch Ramp Multiplier",
                value: fetchRampMultiplierBinding,
                description: "Determines how aggressively Echo expands fetch sizes after initial batches.",
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
                    var updated = settings
                    updated.resultsInitialRowLimit = ResultStreamingDefaults.initialRows
                    updated.resultsPreviewBatchSize = ResultStreamingDefaults.previewBatch
                    updated.resultsBackgroundStreamingThreshold = ResultStreamingDefaults.backgroundThreshold
                    updated.resultsStreamingFetchSize = ResultStreamingDefaults.fetchSize
                    updated.resultsStreamingFetchRampMultiplier = ResultStreamingDefaults.fetchRampMultiplier
                    updated.resultsStreamingFetchRampMax = ResultStreamingDefaults.fetchRampMax
                    updated.resultsUseCursorStreaming = ResultStreamingDefaults.useCursor
                    updated.resultsCursorStreamingLimitThreshold = ResultStreamingDefaults.cursorLimitThreshold
                    Task { try? await projectStore.updateGlobalSettings(updated) }
                }
                .buttonStyle(.bordered)
                .disabled(sharedExecutionSettingsAreDefault)
            }
            .padding(.top, SpacingTokens.xxs2)
        } footer: {
            Text("These defaults shape how Echo ingests large result sets before any engine-specific overrides are applied.")
        }
    }

    @ViewBuilder
    private var postgresSettings: some View {
        Section("Managed Console") {
            SettingsRowWithInfo(
                title: "Enable Postgres Console",
                description: "The Postgres Console is Echo's managed PostgreSQL console powered by the app's Postgres engine. It is the safe default for current builds and does not pretend to be the native psql CLI."
            ) {
                Toggle("", isOn: managedConsoleBinding)
                    .labelsHidden()
            }
        } footer: {
            Text("Use this for the current PostgreSQL console inside Echo. Native psql is configured separately.")
        }

        Section("Native psql") {
            SettingsRowWithInfo(
                title: "Enable Native psql",
                description: "Expose the future native psql entry point in Echo. This currently controls policy and UI availability only; the actual terminal-backed implementation is not wired in yet."
            ) {
                Toggle("", isOn: nativePsqlBinding)
                    .labelsHidden()
            }

            Picker("Runtime Preference", selection: runtimePreferenceBinding) {
                ForEach(NativePsqlRuntimePreference.allCases, id: \.self) { preference in
                    Text(preference.displayName)
                        .tag(preference)
                }
            }
            .disabled(!settings.nativePsqlEnabled)

            SettingsRowWithInfo(
                title: "Allow System Binary Fallback",
                description: "If Echo cannot use its preferred psql runtime, allow a later implementation to fall back to a system-installed psql binary."
            ) {
                Toggle("", isOn: systemFallbackBinding)
                    .labelsHidden()
            }
            .disabled(!settings.nativePsqlEnabled)
        } footer: {
            Text("Native psql is intended for exact CLI compatibility. In shared or managed environments, this should eventually be governed by admin policy instead of only local preferences.")
        }

        Section("Execution Profile") {
            DatabaseStreamingModeRow(selection: postgresModeBinding)

            StreamingPresetPickerControl(
                title: "Cursor Threshold",
                value: cursorLimitThresholdBinding,
                description: "LIMIT at or below this threshold uses the simple path. Larger or unbounded results switch to a server-side cursor.",
                presets: streamingThresholdPresets,
                range: 0...1_000_000,
                formatter: formatRowCount,
                defaultValue: ResultStreamingDefaults.cursorLimitThreshold
            )

            StreamingPresetPickerControl(
                title: "Cursor Fetch Size",
                value: backgroundFetchSizeBinding,
                description: "Recommended at 4,096 or higher for large PostgreSQL result sets.",
                presets: streamingFetchPresets,
                range: 128...16_384,
                formatter: formatRowCount,
                defaultValue: ResultStreamingDefaults.fetchSize
            )
        }

        Section("Future Restrictions") {
            SettingsRowWithInfo(
                title: "Allow Shell Escape",
                description: "Controls whether a future native psql session should permit shell escape commands such as \\!."
            ) {
                Toggle("", isOn: shellEscapeBinding)
                    .labelsHidden()
            }
            .disabled(!settings.nativePsqlEnabled)

            SettingsRowWithInfo(
                title: "Allow File Commands",
                description: "Controls whether a future native psql session should permit filesystem-driven commands such as \\i and copy workflows that depend on local files."
            ) {
                Toggle("", isOn: fileCommandsBinding)
                    .labelsHidden()
            }
            .disabled(!settings.nativePsqlEnabled)
        } footer: {
            Text("These toggles establish the policy model now so the app can grow into a manageable enterprise solution without redesigning database settings later.")
        }
    }

    @ViewBuilder
    private var sqlServerSettings: some View {
        Section("Execution Profile") {
            DatabaseStreamingModeRow(selection: mssqlModeBinding)
        } footer: {
            Text("SQL Server currently supports a managed execution profile only. Agent and job settings should live here if they become configurable later.")
        }
    }

    @ViewBuilder
    private var mySQLSettings: some View {
        Section("Execution Profile") {
            Text("MySQL streams results directly without explicit cursors or engine profile controls in the current implementation.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var sqliteSettings: some View {
        Section("Execution Profile") {
            Text("SQLite runs in-process, so network streaming and cursor profile controls do not currently apply.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var sharedExecutionSettingsAreDefault: Bool {
        settings.resultsInitialRowLimit == ResultStreamingDefaults.initialRows &&
        settings.resultsPreviewBatchSize == ResultStreamingDefaults.previewBatch &&
        settings.resultsBackgroundStreamingThreshold == ResultStreamingDefaults.backgroundThreshold &&
        settings.resultsStreamingFetchSize == ResultStreamingDefaults.fetchSize &&
        settings.resultsStreamingFetchRampMultiplier == ResultStreamingDefaults.fetchRampMultiplier &&
        settings.resultsStreamingFetchRampMax == ResultStreamingDefaults.fetchRampMax &&
        settings.resultsUseCursorStreaming == ResultStreamingDefaults.useCursor &&
        settings.resultsCursorStreamingLimitThreshold == ResultStreamingDefaults.cursorLimitThreshold
    }

    private var initialRowLimitBinding: Binding<Int> {
        intBinding(for: \.resultsInitialRowLimit, min: 100, max: 100_000)
    }

    private var previewBatchSizeBinding: Binding<Int> {
        intBinding(for: \.resultsPreviewBatchSize, min: 100, max: 100_000)
    }

    private var backgroundStreamingThresholdBinding: Binding<Int> {
        intBinding(for: \.resultsBackgroundStreamingThreshold, min: 100, max: 1_000_000)
    }

    private var backgroundFetchSizeBinding: Binding<Int> {
        intBinding(for: \.resultsStreamingFetchSize, min: 128, max: 16_384)
    }

    private var fetchRampMultiplierBinding: Binding<Int> {
        intBinding(for: \.resultsStreamingFetchRampMultiplier, min: 1, max: 64)
    }

    private var fetchRampMaxBinding: Binding<Int> {
        intBinding(for: \.resultsStreamingFetchRampMax, min: 256, max: 1_048_576)
    }

    private var cursorLimitThresholdBinding: Binding<Int> {
        intBinding(for: \.resultsCursorStreamingLimitThreshold, min: 0, max: 1_000_000)
    }

    private var postgresModeBinding: Binding<ResultStreamingExecutionMode> {
        binding(for: \.resultsStreamingMode)
    }

    private var mssqlModeBinding: Binding<ResultStreamingExecutionMode> {
        binding(for: \.mssqlStreamingMode)
    }

    private var managedConsoleBinding: Binding<Bool> {
        binding(for: \.managedPostgresConsoleEnabled)
    }

    private var nativePsqlBinding: Binding<Bool> {
        binding(for: \.nativePsqlEnabled)
    }

    private var runtimePreferenceBinding: Binding<NativePsqlRuntimePreference> {
        binding(for: \.nativePsqlRuntimePreference)
    }

    private var systemFallbackBinding: Binding<Bool> {
        binding(for: \.nativePsqlAllowSystemBinaryFallback)
    }

    private var shellEscapeBinding: Binding<Bool> {
        binding(for: \.nativePsqlAllowShellEscape)
    }

    private var fileCommandsBinding: Binding<Bool> {
        binding(for: \.nativePsqlAllowFileCommands)
    }

    private func formatMultiplier(_ value: Int) -> String {
        "\(value)x"
    }

    private func formatRowCount(_ value: Int) -> String {
        value.formatted()
    }

    private func binding<Value>(for keyPath: WritableKeyPath<GlobalSettings, Value>) -> Binding<Value> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { newValue in
                var updated = settings
                updated[keyPath: keyPath] = newValue
                Task { try? await projectStore.updateGlobalSettings(updated) }
            }
        )
    }

    private func intBinding(for keyPath: WritableKeyPath<GlobalSettings, Int>, min: Int, max: Int) -> Binding<Int> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { newValue in
                let clamped = Swift.max(min, Swift.min(newValue, max))
                guard settings[keyPath: keyPath] != clamped else { return }
                var updated = settings
                updated[keyPath: keyPath] = clamped
                Task { try? await projectStore.updateGlobalSettings(updated) }
            }
        )
    }
}

private struct DatabaseStreamingModeRow: View {
    @Binding var selection: ResultStreamingExecutionMode
    @State private var isPopoverPresented = false

    private static let modeDescriptions: [(mode: ResultStreamingExecutionMode, summary: String)] = [
        (.auto, "Picks the best strategy per query"),
        (.simple, "Fetches all rows in one pass"),
        (.cursor, "Server-side cursor for large results"),
    ]

    var body: some View {
        LabeledContent {
            HStack(spacing: SpacingTokens.xxs2) {
                Picker("", selection: $selection) {
                    ForEach(ResultStreamingExecutionMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)

                Button(action: { isPopoverPresented.toggle() }) {
                    Image(systemName: "info.circle")
                        .imageScale(.medium)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .popover(isPresented: $isPopoverPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .trailing) {
                    VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                        ForEach(Self.modeDescriptions, id: \.mode) { item in
                            HStack(alignment: .top, spacing: SpacingTokens.xs) {
                                Text(item.mode.displayName)
                                    .font(TypographyTokens.standard.weight(.semibold))
                                    .frame(width: 56, alignment: .leading)
                                Text(item.summary)
                                    .font(TypographyTokens.standard)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(SpacingTokens.md)
                    .frame(width: 320)
                }
            }
        } label: {
            Text("Streaming Mode")
        }
    }
}
