import SwiftUI

struct IdentitiesTableView: View {
    let identities: [SavedIdentity]
    @Binding var selection: Set<SavedIdentity.ID>
    @Binding var sortOrder: [KeyPathComparator<SavedIdentity>]
    let folderLookup: [UUID: SavedFolder]
    let onEdit: (SavedIdentity) -> Void
    let onDelete: (SavedIdentity) -> Void
    let moveIdentityToFolder: (SavedIdentity, SavedFolder) -> Void
    let createFolderAndMoveIdentity: (SavedIdentity) -> Void
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        ThemedTableContainer {
            Table(of: SavedIdentity.self, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("") { identity in
                    IdentityIconCell(identity: identity)
                }
                .width(28)

                TableColumn("Name", value: \.name) { identity in
                    LeadingTableCell {
                        Text(identity.name)
                            .multilineTextAlignment(.leading)
                    }
                }

                TableColumn("Username", value: \.username) { identity in
                    let trimmed = identity.username.trimmingCharacters(in: .whitespacesAndNewlines)
                    LeadingTableCell {
                        Text(trimmed.isEmpty ? "—" : trimmed)
                            .foregroundStyle(trimmed.isEmpty ? .secondary : .primary)
                            .multilineTextAlignment(.leading)
                    }
                }

                TableColumn("Folder") { identity in
                    let folderName = identity.folderID.flatMap { folderLookup[$0]?.displayName } ?? "—"
                    LeadingTableCell {
                        Text(folderName)
                            .foregroundStyle(folderName == "—" ? .secondary : .primary)
                            .multilineTextAlignment(.leading)
                    }
                }

                TableColumn("Updated") { identity in
                    let referenceDate = identity.updatedAt ?? identity.createdAt
                    LeadingTableCell {
                        Text(referenceDate, style: .date)
                            .multilineTextAlignment(.leading)
                    }
                }

            } rows: {
                ForEach(identities) { identity in
                    TableRow(identity)
                        .itemProvider {
                            NSItemProvider(object: "identity:\(identity.id.uuidString)" as NSString)
                        }
                }
            }
            .contextMenu {
                if let selectionID = selection.first,
                   let identity = identities.first(where: { $0.id == selectionID }) {
                    Button {
                        onEdit(identity)
                    } label: {
                        Text("Edit")
                    }

                    Menu("Move to Folder") {
                        ForEach(Array(folderLookup.values).sorted(by: { $0.name < $1.name }), id: \.id) { folder in
                            Button(folder.displayName) {
                                moveIdentityToFolder(identity, folder)
                            }
                        }
                        Divider()
                        Button("Create New Folder...") {
                            createFolderAndMoveIdentity(identity)
                        }
                    }

                    Divider()

                    Button("Delete", role: .destructive) { onDelete(identity) }
                }
            }
        }
    }
}
