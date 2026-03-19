import SwiftUI

struct QueryResultsSettingsView: View {
    @Environment(ProjectStore.self) internal var projectStore
    @Environment(AppearanceStore.self) internal var appearanceStore

    var body: some View {
        Form {
            Section("Appearance") {
                PropertyRow(
                    title: "Show row numbers",
                    info: "Displays a numbered index column on the leading edge of the results table."
                ) {
                    Toggle("", isOn: showRowNumbersBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                PropertyRow(
                    title: "Alternate row shading",
                    info: "Applies alternating background colors to result table rows for easier reading."
                ) {
                    Toggle("", isOn: alternateRowShadingBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            Section("Cell Inspector") {
                PropertyRow(
                    title: "Foreign keys in inspector",
                    info: "Show referenced row details when selecting a foreign key cell."
                ) {
                    Toggle("", isOn: showForeignKeysInInspectorBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                PropertyRow(
                    title: "JSON values in inspector",
                    info: "Show formatted JSON when selecting a JSON or JSONB cell."
                ) {
                    Toggle("", isOn: showJsonInInspectorBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                PropertyRow(
                    title: "Auto-open inspector",
                    info: "Automatically open and close the inspector panel based on cell selection."
                ) {
                    Toggle("", isOn: autoOpenInspectorBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            Section("Bottom Panel") {
                PropertyRow(
                    title: "Auto-open on activity",
                    info: "Automatically open the bottom panel when a query executes or an operation produces messages."
                ) {
                    Toggle("", isOn: autoOpenBottomPanelBinding)
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
