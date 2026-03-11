import SwiftUI

struct PostgresToolsSettingsView: View {
    @Environment(ProjectStore.self) private var projectStore

    private var settings: GlobalSettings {
        projectStore.globalSettings
    }

    var body: some View {
        Form {
            Section {
                SettingsRowWithInfo(
                    title: "Enable Postgres Console",
                    description: "The Postgres Console is Echo's managed PostgreSQL console powered by the app's Postgres engine. It is the safe default for current builds and does not pretend to be the native psql CLI."
                ) {
                    Toggle("", isOn: managedConsoleBinding)
                        .labelsHidden()
                }
            } header: {
                Text("Managed Console")
            } footer: {
                Text("Use this for the current Postgres console inside Echo. Native psql is configured separately.")
            }

            Section {
                SettingsRowWithInfo(
                    title: "Enable Native psql",
                    description: "Expose the future native psql entry point in Echo. This setting only controls feature availability and policy right now; the actual terminal-backed implementation is not wired in yet."
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
            } header: {
                Text("Native psql")
            } footer: {
                Text("Native psql is intended for exact CLI compatibility. In shared or managed environments, this should eventually be governed by admin policy instead of only local preferences.")
            }

            Section {
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
            } header: {
                Text("Future Restrictions")
            } footer: {
                Text("These toggles establish the policy model now so the app can grow into a manageable enterprise solution without redesigning settings later.")
            }
        }
        .formStyle(.grouped)
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
}
