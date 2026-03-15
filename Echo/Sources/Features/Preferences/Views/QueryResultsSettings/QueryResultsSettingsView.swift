import SwiftUI

struct QueryResultsSettingsView: View {
    @Environment(ProjectStore.self) internal var projectStore
    @Environment(AppearanceStore.self) internal var appearanceStore

    var body: some View {
        Form {
            Section("Appearance") {
                SettingsRowWithInfo(
                    title: "Show row numbers",
                    description: "Displays a numbered index column on the leading edge of the results table."
                ) {
                    Toggle("", isOn: showRowNumbersBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                SettingsRowWithInfo(
                    title: "Alternate row shading",
                    description: "Applies alternating background colors to result table rows for easier reading."
                ) {
                    Toggle("", isOn: alternateRowShadingBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            Section("Cell Inspector") {
                SettingsRowWithInfo(
                    title: "Foreign keys in inspector",
                    description: "Show referenced row details when selecting a foreign key cell."
                ) {
                    Toggle("", isOn: showForeignKeysInInspectorBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                SettingsRowWithInfo(
                    title: "JSON values in inspector",
                    description: "Show formatted JSON when selecting a JSON or JSONB cell."
                ) {
                    Toggle("", isOn: showJsonInInspectorBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                SettingsRowWithInfo(
                    title: "Auto-open inspector",
                    description: "Automatically open and close the inspector panel based on cell selection."
                ) {
                    Toggle("", isOn: autoOpenInspectorBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            ResultGridColorSettingsSection()
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}
