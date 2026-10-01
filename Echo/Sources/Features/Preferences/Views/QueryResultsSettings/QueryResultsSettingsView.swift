import EchoSense
import SwiftUI

struct QueryResultsSettingsView: View {
    @Environment(ProjectStore.self) internal var projectStore
    @Environment(AppearanceStore.self) internal var appearanceStore

    var body: some View {
        SettingsPage(
            previewHeight: 190,
            resetPage: projectStore.resetPage(Self.resettable),
            preview: { ResultsSettingsPreview(settings: projectStore.globalSettings) }
        ) {
            Section("Appearance") {
                PropertyRow(
                    title: "Show row numbers",
                    info: "Displays a numbered index column on the leading edge of the results table.",
                    resetAction: projectStore.resetAction(\.resultsShowRowNumbers)
                ) {
                    Toggle("", isOn: showRowNumbersBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                PropertyRow(
                    title: "Alternate row shading",
                    info: "Applies alternating background colors to result table rows for easier reading.",
                    resetAction: projectStore.resetAction(\.resultsAlternateRowShading)
                ) {
                    Toggle("", isOn: alternateRowShadingBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                PropertyRow(
                    title: "Selection summary",
                    info: "What the footer's cell count also says about selected numbers. The popover always lists every figure.",
                    resetAction: projectStore.resetAction(\.resultsSelectionPill)
                ) {
                    Picker("", selection: projectStore.globalSettingBinding(\.resultsSelectionPill)) {
                        ForEach(SelectionPillFigures.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }

                PropertyRow(
                    title: "Monospaced cells",
                    info: "Shows every cell in the editor's monospaced font. Numbers always use aligned digits.",
                    resetAction: projectStore.resetAction(\.resultsMonospacedCells)
                ) {
                    Toggle("", isOn: projectStore.globalSettingBinding(\.resultsMonospacedCells))
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
    }

    /// Everything Reset This Page puts back.
    static let resettable: [ResettableSetting] = [
        .init(\.resultsShowRowNumbers), .init(\.resultsAlternateRowShading), .init(\.resultsSelectionPill), .init(\.resultsMonospacedCells),
    ]
}
