import SwiftUI

struct MySQLServerStatusVariablesSection: View {
    @Bindable var viewModel: ServerPropertiesViewModel

    @State private var selectedCategory = "All"
    @State private var selectedStatusVariableID: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            TabSectionToolbar {
                HStack(spacing: SpacingTokens.sm) {
                    TextField("", text: $viewModel.searchText, prompt: Text("Filter status variables"))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 260)

                    Picker("Category", selection: $selectedCategory) {
                        Text("All").tag("All")
                        ForEach(statusCategories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 160)
                }
            } controls: {
                Button("Refresh") {
                    Task { await viewModel.loadCurrentSection() }
                }
                .buttonStyle(.borderless)
            }

            Divider()

            Table(filteredStatusVariables, selection: $selectedStatusVariableID) {
                TableColumn("Variable") { item in
                    Text(item.name)
                        .font(TypographyTokens.Table.name)
                }
                .width(min: 200, ideal: 260)

                TableColumn("Value") { item in
                    Text(item.value)
                        .font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .textSelection(.enabled)
                }
                .width(min: 200, ideal: 320)

                TableColumn("Category") { item in
                    Text(item.category ?? "GENERAL")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                .width(min: 100, ideal: 120)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .tableColumnAutoResize()

            Divider()

            Group {
                if let selectedStatusVariable {
                    VStack(alignment: .leading, spacing: SpacingTokens.md) {
                        Text(selectedStatusVariable.name)
                            .font(TypographyTokens.prominent.weight(.semibold))

                        PropertyRow(title: "Current Value") {
                            Text(selectedStatusVariable.value)
                                .font(TypographyTokens.monospaced)
                                .foregroundStyle(ColorTokens.Text.secondary)
                                .textSelection(.enabled)
                        }

                        PropertyRow(title: "Category") {
                            Text(selectedStatusVariable.category ?? "GENERAL")
                                .foregroundStyle(ColorTokens.Text.secondary)
                        }
                    }
                    .padding(SpacingTokens.md)
                } else {
                    ContentUnavailableView {
                        Label("No Status Variable Selected", systemImage: "waveform.path.ecg")
                    } description: {
                        Text("Select a MySQL status variable to inspect its live value.")
                    }
                    .padding(SpacingTokens.lg)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            if selectedStatusVariableID.isEmpty, let first = filteredStatusVariables.first {
                selectedStatusVariableID = [first.id]
            }
        }
        .onChange(of: selectedCategory) { _, _ in
            refreshSelection()
        }
        .onChange(of: viewModel.searchText) { _, _ in
            refreshSelection()
        }
    }

    private var filteredStatusVariables: [ServerPropertiesViewModel.PropertyItem] {
        let items = viewModel.filteredStatusVariables
        guard selectedCategory != "All" else { return items }
        return items.filter { $0.category == selectedCategory }
    }

    private var statusCategories: [String] {
        Array(Set(viewModel.statusVariables.compactMap(\.category)))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var selectedStatusVariable: ServerPropertiesViewModel.PropertyItem? {
        filteredStatusVariables.first { selectedStatusVariableID.contains($0.id) }
    }

    private func refreshSelection() {
        if !filteredStatusVariables.contains(where: { selectedStatusVariableID.contains($0.id) }) {
            selectedStatusVariableID = filteredStatusVariables.first.map { [$0.id] } ?? []
        }
    }
}
