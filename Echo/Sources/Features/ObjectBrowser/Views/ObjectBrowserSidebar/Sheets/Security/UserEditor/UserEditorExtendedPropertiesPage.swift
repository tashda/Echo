import SwiftUI

struct UserEditorExtendedPropertiesPage: View {
    @Bindable var viewModel: UserEditorViewModel

    var body: some View {
        if viewModel.isLoadingExtendedProperties {
            Section {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Loading extended properties\u{2026}")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        } else if !viewModel.isEditing {
            Section {
                Text("Extended properties can be added after the user is created.")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        } else {
            Section {
                HStack {
                    Button("Add Property") { addProperty() }
                        .buttonStyle(.bordered)

                    if viewModel.selectedPropertyID != nil {
                        Button("Delete") { deleteSelectedProperty() }
                            .buttonStyle(.bordered)
                    }

                    Spacer()
                }

                if activeEntries.isEmpty {
                    Text("No extended properties defined.")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                } else {
                    Table(activeEntries, selection: $viewModel.selectedPropertyID) {
                        TableColumn("Name") { entry in
                            if let index = entryIndex(for: entry.id) {
                                TextField(
                                    "", text: $viewModel.extendedPropertyEntries[index].name,
                                    prompt: Text("property_name")
                                )
                                .textFieldStyle(.plain)
                            }
                        }
                        .width(min: 120, ideal: 180)

                        TableColumn("Value") { entry in
                            if let index = entryIndex(for: entry.id) {
                                TextField(
                                    "", text: $viewModel.extendedPropertyEntries[index].value,
                                    prompt: Text("value")
                                )
                                .textFieldStyle(.plain)
                            }
                        }
                        .width(min: 200, ideal: 300)
                    }
                    .tableStyle(.inset(alternatesRowBackgrounds: true))
                    .frame(minHeight: 120, maxHeight: 300)
                }
            } header: {
                Text("Extended Properties")
            }
        }
    }

    // MARK: - Helpers

    private var activeEntries: [ExtendedPropertyEntry] {
        viewModel.extendedPropertyEntries.filter { !$0.isDeleted }
    }

    private func entryIndex(for id: UUID) -> Int? {
        viewModel.extendedPropertyEntries.firstIndex { $0.id == id }
    }

    private func addProperty() {
        let entry = ExtendedPropertyEntry(
            id: UUID(),
            name: "",
            value: "",
            isNew: true,
            originalName: nil,
            originalValue: nil
        )
        viewModel.extendedPropertyEntries.append(entry)
        viewModel.selectedPropertyID = entry.id
    }

    private func deleteSelectedProperty() {
        guard let selectedID = viewModel.selectedPropertyID,
              let index = entryIndex(for: selectedID) else { return }

        if viewModel.extendedPropertyEntries[index].isNew {
            viewModel.extendedPropertyEntries.remove(at: index)
        } else {
            viewModel.extendedPropertyEntries[index].isDeleted = true
        }
        viewModel.selectedPropertyID = nil
    }
}
