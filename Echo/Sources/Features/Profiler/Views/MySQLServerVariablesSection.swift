import SwiftUI

struct MySQLServerVariablesSection: View {
    @Bindable var viewModel: ServerPropertiesViewModel
    @Binding var showVariableEditor: Bool
    @Environment(EnvironmentState.self) private var environmentState

    @State private var selectedCategory: String = "All"

    var body: some View {
        VStack(spacing: 0) {
            ServerPropertiesVariablesTable(
                items: filteredVariables,
                selection: $viewModel.selectedVariableID
            )

            Divider()

            variableDetailPanel
        }
        .toolTabHeaderControls { headerControls }
        .tabToolbar(special: editItem, groups: [toolbarGroup])
    }

    /// Category and search on the tool's header line (round 37.2).
    @ViewBuilder
    private var headerControls: some View {
        ToolTabPickerPill(title: "Category", systemImage: "line.3.horizontal.decrease", selection: $selectedCategory,
                          options: ["All"] + viewModel.variableCategories, label: { $0 })
        ToolTabSearchField(prompt: "Filter variables", text: $viewModel.searchText)
    }

    /// Round 37.5: Edit is the special button; the scripts, Reset and Refresh the group.
    private var editItem: TabToolbarItem {
        TabToolbarItem(id: "edit", title: "Edit", symbol: "pencil", isDisabled: viewModel.selectedVariable == nil) { showVariableEditor = true }
    }

    private var toolbarGroup: [TabToolbarItem] {
        [
            TabToolbarItem(id: "scriptSet", title: "Script SET", symbol: "doc.text", isDisabled: selectedVariable == nil) {
                if let sql = selectedVariable.map(setSQL(for:)) { openQueryTab(sql) }
            },
            TabToolbarItem(id: "scriptReset", title: "Script RESET", symbol: "doc.text.below.ecg", isDisabled: selectedVariable == nil) {
                if let sql = selectedVariable.map(resetSQL(for:)) { openQueryTab(sql) }
            },
            TabToolbarItem(id: "reset", title: "Reset to Default", symbol: "arrow.uturn.backward", isDisabled: viewModel.selectedVariable == nil) { [viewModel] in
                Task { await viewModel.resetSelectedVariable() }
            },
            .refresh { [viewModel] in Task { await viewModel.loadCurrentSection() } },
        ]
    }

    private var filteredVariables: [ServerPropertiesViewModel.PropertyItem] {
        let items = viewModel.filteredVariables
        guard selectedCategory != "All" else { return items }
        return items.filter { $0.category == selectedCategory }
    }

    private var selectedVariable: ServerPropertiesViewModel.PropertyItem? {
        filteredVariables.first { viewModel.selectedVariableID.contains($0.id) }
            ?? viewModel.selectedVariable
    }

    @ViewBuilder
    private var variableDetailPanel: some View {
        if let variable = selectedVariable {
            VStack(alignment: .leading, spacing: SpacingTokens.md) {
                HStack {
                    VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                        Text(variable.name)
                            .font(TypographyTokens.prominent.weight(.semibold))
                        Text(variable.category ?? "GENERAL")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }

                    Spacer()

                    HStack(spacing: SpacingTokens.sm) {
                        Button("Script SET") { openQueryTab(setSQL(for: variable)) }
                            .buttonStyle(.bordered)
                        Button("Script RESET") { openQueryTab(resetSQL(for: variable)) }
                            .buttonStyle(.bordered)
                    }
                }

                PropertyRow(title: "Current Value") {
                    Text(variable.value)
                        .font(TypographyTokens.monospaced)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .textSelection(.enabled)
                }

                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Text("Generated SET GLOBAL")
                        .font(TypographyTokens.formLabel)
                    Text(setSQL(for: variable))
                        .font(TypographyTokens.monospaced)
                        .textSelection(.enabled)
                        .padding(SpacingTokens.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ColorTokens.Background.secondary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(SpacingTokens.md)
        } else {
            ContentUnavailableView {
                Label("No Variable Selected", systemImage: "slider.horizontal.3")
            } description: {
                Text("Select a MySQL global variable to inspect its current value or generate management SQL.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(SpacingTokens.lg)
        }
    }

    private func setSQL(for variable: ServerPropertiesViewModel.PropertyItem) -> String {
        "SET GLOBAL `\(escapedIdentifier(variable.name))` = \(variable.value);"
    }

    private func resetSQL(for variable: ServerPropertiesViewModel.PropertyItem) -> String {
        "SET GLOBAL `\(escapedIdentifier(variable.name))` = DEFAULT;"
    }

    private func escapedIdentifier(_ value: String) -> String {
        value.replacingOccurrences(of: "`", with: "``")
    }

    private func openQueryTab(_ sql: String) {
        environmentState.openScriptTab(sql: sql, connectionID: viewModel.connectionID)
    }
}

private struct ServerPropertiesVariablesTable: View {
    let items: [ServerPropertiesViewModel.PropertyItem]
    @Binding var selection: Set<String>

    var body: some View {
        Table(items, selection: $selection) {
            TableColumn("Variable") { item in
                Text(item.name)
                    .font(TypographyTokens.Table.name)
            }
            .width(min: 180, ideal: 240)

            TableColumn("Value") { item in
                Text(item.value)
                    .font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .textSelection(.enabled)
            }
            .width(min: 240, ideal: 420)

            TableColumn("Category") { item in
                Text(item.category ?? "GENERAL")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 90, ideal: 120)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
    }
}
