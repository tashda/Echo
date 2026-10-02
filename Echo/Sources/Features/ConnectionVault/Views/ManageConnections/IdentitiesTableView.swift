import SwiftUI

struct IdentitiesTableView: View {
    let identities: [SavedIdentity]
    @Binding var selection: Set<SavedIdentity.ID>
    @Binding var sortOrder: [KeyPathComparator<SavedIdentity>]
    let folderLookup: [UUID: SavedFolder]
    let onEdit: (SavedIdentity) -> Void
    let onDelete: (SavedIdentity) -> Void
    let onNewIdentity: () -> Void

    var body: some View {
        Table(of: SavedIdentity.self, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("") { identity in
                IdentityIconCell(identity: identity)
            }
            .width(24)

            TableColumn("Name") { identity in
                Text(identity.name)
                    .font(TypographyTokens.Table.name)
            }

            TableColumn("Authentication") { identity in
                Text(identity.authenticationMethod.displayName)
                    .font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            TableColumn("Username", value: \.username) { identity in
                let trimmed = identity.username.trimmingCharacters(in: .whitespacesAndNewlines)
                Text(trimmed.isEmpty ? "\u{2014}" : trimmed)
                    .font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(trimmed.isEmpty ? ColorTokens.Text.tertiary : ColorTokens.Text.primary)
            }

            // Round MC (MB1): identity folders retire; an old folder shows as a group until it empties.
            TableColumn("Group") { identity in
                let folderName = identity.folderID.flatMap { folderLookup[$0]?.displayName }
                Text(folderName ?? "\u{2014}")
                    .font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(folderName == nil ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
            }

            TableColumn("Updated") { identity in
                let referenceDate = identity.updatedAt ?? identity.createdAt
                Text(referenceDate, style: .date)
                    .font(TypographyTokens.Table.date)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

        } rows: {
            ForEach(identities) { identity in
                TableRow(identity)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .contextMenu(forSelectionType: SavedIdentity.ID.self) { items in
            if let selectionID = items.first,
               let identity = identities.first(where: { $0.id == selectionID }) {
                Button("Edit") { onEdit(identity) }

                Divider()
                Button("Delete", role: .destructive) { onDelete(identity) }
            } else {
                Button("New Identity") { onNewIdentity() }
            }
        } primaryAction: { items in
            if let selectionID = items.first,
               let identity = identities.first(where: { $0.id == selectionID }) {
                onEdit(identity)
            }
        }
    }
}
