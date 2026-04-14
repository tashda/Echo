import SwiftUI

struct UserEditorOwnedSchemasPage: View {
    @Bindable var viewModel: UserEditorViewModel

    var body: some View {
        if viewModel.isLoadingSchemas {
            Section {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Loading schemas\u{2026}")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        } else if viewModel.schemaEntries.isEmpty {
            Section {
                Text("No schemas available in this database.")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        } else {
            Section("Schema Ownership") {
                ForEach($viewModel.schemaEntries) { $entry in
                    PropertyRow(
                        title: entry.name,
                        subtitle: ownerSubtitle(for: entry)
                    ) {
                        Toggle("", isOn: $entry.isOwned)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    .disabled(entry.isSystemSchema)
                }
            }
        }
    }

    private func ownerSubtitle(for entry: SchemaOwnerEntry) -> String? {
        guard let owner = entry.currentOwner, !owner.isEmpty else { return nil }
        if entry.isOwned { return nil }
        return "Owner: \(owner)"
    }
}
