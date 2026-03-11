import SwiftUI

extension DatabasesSettingsView {

    /// PostgreSQL-specific settings: managed console, native psql policy, execution profile, restrictions.
    @ViewBuilder
    var postgresSettings: some View {
        Section("Managed Console") {
            SettingsRowWithInfo(
                title: "Enable Postgres Console",
                description: "The Postgres Console is Echo's managed PostgreSQL console powered by the app's Postgres engine. Use this for the current PostgreSQL console inside Echo. Native psql is configured separately."
            ) {
                Toggle("", isOn: managedConsoleBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }

        Section("Native psql") {
            SettingsRowWithInfo(
                title: "Enable Native psql",
                description: "Expose the future native psql entry point in Echo. This currently controls policy and UI availability only. Native psql is intended for exact CLI compatibility."
            ) {
                Toggle("", isOn: nativePsqlBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
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
                description: "If Echo cannot use its preferred psql runtime, allow falling back to a system-installed psql binary."
            ) {
                Toggle("", isOn: systemFallbackBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            .disabled(!settings.nativePsqlEnabled)
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

        Section("Restrictions") {
            SettingsRowWithInfo(
                title: "Allow Shell Escape",
                description: "Controls whether a future native psql session should permit shell escape commands such as \\!. These toggles establish the policy model now so the app can grow without redesigning database settings later."
            ) {
                Toggle("", isOn: shellEscapeBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            .disabled(!settings.nativePsqlEnabled)

            SettingsRowWithInfo(
                title: "Allow File Commands",
                description: "Controls whether a future native psql session should permit filesystem-driven commands such as \\i and copy workflows."
            ) {
                Toggle("", isOn: fileCommandsBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            .disabled(!settings.nativePsqlEnabled)
        }
    }
}
