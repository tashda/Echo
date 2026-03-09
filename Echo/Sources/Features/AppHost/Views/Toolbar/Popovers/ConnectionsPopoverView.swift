import SwiftUI

/// SwiftUI view for the connections breadcrumb popover.
///
/// Displays a filter field, recent connections, folder-grouped connections,
/// and action items. Shown inside an `NSPopover` via `NSHostingController`
/// from `BreadcrumbBarView`.
struct ConnectionsPopoverView: View {
    let connectionStore: ConnectionStore
    let environmentState: EnvironmentState
    let dismiss: () -> Void

    @State private var filter = ""

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            connectionsList
        }
        .frame(width: 260, height: 380)
        .background(.clear)
    }

    // MARK: - Search

    private var searchField: some View {
        TextField("Filter", text: $filter)
            .textFieldStyle(.roundedBorder)
            .controlSize(.small)
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.vertical, SpacingTokens.xs)
    }

    // MARK: - List

    private var connectionsList: some View {
        List {
            if filter.isEmpty, !recentConnections.isEmpty {
                Section("Recent") {
                    ForEach(recentConnections) { conn in
                        connectionRow(conn)
                    }
                }
            }

            ForEach(folderSections, id: \.folder.id) { section in
                Section(section.folder.name) {
                    ForEach(section.connections) { conn in
                        connectionRow(conn)
                    }
                }
            }

            if !unfiledConnections.isEmpty {
                Section(folderSections.isEmpty ? "" : "Other") {
                    ForEach(unfiledConnections) { conn in
                        connectionRow(conn)
                    }
                }
            }

            Section {
                Button {
                    ManageConnectionsWindowController.shared.present()
                    dismiss()
                } label: {
                    Label("Manage Connections\u{2026}", systemImage: "gearshape")
                }

                Button {
                    ManageConnectionsWindowController.shared.present()
                    dismiss()
                } label: {
                    Label("Quick Connect\u{2026}", systemImage: "bolt")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Row

    @ViewBuilder
    private func connectionRow(_ connection: SavedConnection) -> some View {
        let isSelected = connection.id == connectionStore.selectedConnectionID

        Button {
            Task { await environmentState.connect(to: connection) }
            dismiss()
        } label: {
            HStack(spacing: SpacingTokens.xs) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 14)
                } else {
                    Color.clear.frame(width: 14)
                }

                connectionIcon(connection)
                    .frame(width: 16, height: 16)

                Text(displayName(connection))
                    .font(TypographyTokens.standard)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func connectionIcon(_ connection: SavedConnection) -> some View {
        if let image = NSImage(named: connection.databaseType.iconName) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "server.rack")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Data

    private var projectID: UUID? {
        AppCoordinator.shared.projectStore.selectedProject?.id
    }

    private var recentConnections: [SavedConnection] {
        Array(environmentState.recentConnections.prefix(3)).compactMap { record in
            connectionStore.connections.first { $0.id == record.id }
        }
    }

    private struct FolderSection {
        let folder: SavedFolder
        let connections: [SavedConnection]
    }

    private var folderSections: [FolderSection] {
        connectionStore.folders
            .filter { $0.kind == .connections && $0.parentFolderID == nil && $0.projectID == projectID }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .compactMap { folder in
                let conns = connectionStore.connections
                    .filter { $0.folderID == folder.id && $0.projectID == projectID }
                    .filter { matches($0) }
                    .sorted { displayName($0).localizedCaseInsensitiveCompare(displayName($1)) == .orderedAscending }
                guard !conns.isEmpty else { return nil }
                return FolderSection(folder: folder, connections: conns)
            }
    }

    private var unfiledConnections: [SavedConnection] {
        connectionStore.connections
            .filter { $0.folderID == nil && $0.projectID == projectID }
            .filter { matches($0) }
            .sorted { displayName($0).localizedCaseInsensitiveCompare(displayName($1)) == .orderedAscending }
    }

    // MARK: - Helpers

    private func displayName(_ conn: SavedConnection) -> String {
        let trimmed = conn.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? conn.host : trimmed
    }

    private func matches(_ conn: SavedConnection) -> Bool {
        guard !filter.isEmpty else { return true }
        return displayName(conn).localizedCaseInsensitiveContains(filter)
    }
}
