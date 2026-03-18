import SwiftUI

extension DatabasesSettingsView {

    /// PostgreSQL-specific settings: managed console, native psql policy, restrictions.
    @ViewBuilder
    var postgresSettings: some View {
        Section("Managed Console") {
            PropertyRow(
                title: "Enable Postgres Console",
                info: "The Postgres Console is Echo's managed PostgreSQL console powered by the app's Postgres engine. Use this for the current PostgreSQL console inside Echo. Native psql is configured separately."
            ) {
                Toggle("", isOn: managedConsoleBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }

        Section("Native psql") {
            PropertyRow(
                title: "Enable Native psql",
                info: "Expose the future native psql entry point in Echo. This currently controls policy and UI availability only. Native psql is intended for exact CLI compatibility."
            ) {
                Toggle("", isOn: nativePsqlBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            PropertyRow(title: "Runtime Preference") {
                Picker("", selection: runtimePreferenceBinding) {
                    ForEach(NativePsqlRuntimePreference.allCases, id: \.self) { preference in
                        Text(preference.displayName)
                            .tag(preference)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
            .disabled(!settings.nativePsqlEnabled)

            PropertyRow(
                title: "Allow System Binary Fallback",
                info: "If Echo cannot use its preferred psql runtime, allow falling back to a system-installed psql binary."
            ) {
                Toggle("", isOn: systemFallbackBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            .disabled(!settings.nativePsqlEnabled)
        }

        Section("Restrictions") {
            PropertyRow(
                title: "Allow Shell Escape",
                info: "Controls whether a future native psql session should permit shell escape commands such as \\!. These toggles establish the policy model now so the app can grow without redesigning database settings later."
            ) {
                Toggle("", isOn: shellEscapeBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            .disabled(!settings.nativePsqlEnabled)

            PropertyRow(
                title: "Allow File Commands",
                info: "Controls whether a future native psql session should permit filesystem-driven commands such as \\i and copy workflows."
            ) {
                Toggle("", isOn: fileCommandsBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            .disabled(!settings.nativePsqlEnabled)
        }
    }
}
