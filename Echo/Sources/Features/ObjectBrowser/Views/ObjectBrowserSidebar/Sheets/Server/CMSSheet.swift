import SwiftUI
import SQLServerKit

/// Panel showing Central Management Server groups and registered servers.
struct CMSSheet: View {
    let session: ConnectionSession
    let onDismiss: () -> Void

    @State var isLoading = true
    @State var errorMessage: String?
    @State var groups: [SQLServerCMSGroup] = []
    @State var servers: [SQLServerCMSServer] = []

    var body: some View {
        SheetLayout(
            title: "Central Management Servers",
            icon: "server.rack",
            primaryAction: "Done",
            canSubmit: true,
            isSubmitting: false,
            errorMessage: errorMessage,
            onSubmit: { onDismiss() },
            onCancel: { onDismiss() }
        ) {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if groups.isEmpty && servers.isEmpty {
                    ContentUnavailableView(
                        "No Registered Servers",
                        systemImage: "server.rack",
                        description: Text("No CMS groups or servers are registered on this instance.")
                    )
                } else {
                    treeList
                }
            }
        }
        .frame(minWidth: 520, idealWidth: 600, minHeight: 380, idealHeight: 460)
        .task { await loadData() }
    }

    // MARK: - Tree List

    private var treeList: some View {
        List {
            let flatItems = buildFlatTree()
            ForEach(flatItems, id: \.id) { item in
                switch item.kind {
                case .group(let group):
                    groupRow(group)
                        .padding(.leading, CGFloat(item.depth) * SpacingTokens.md)
                        .listRowSeparator(.hidden)
                case .server(let server):
                    serverRow(server)
                        .padding(.leading, CGFloat(item.depth) * SpacingTokens.md)
                        .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Rows

    private func groupRow(_ group: SQLServerCMSGroup) -> some View {
        HStack(spacing: SpacingTokens.sm) {
            Image(systemName: "folder")
                .foregroundStyle(ColorTokens.accent)
                .frame(width: 16)
            Text(group.name)
                .font(TypographyTokens.standard.weight(.medium))
                .lineLimit(1)
            if !group.description.isEmpty {
                Text(group.description)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 0)
        }
    }

    private func serverRow(_ server: SQLServerCMSServer) -> some View {
        HStack(spacing: SpacingTokens.sm) {
            Image(systemName: "desktopcomputer")
                .foregroundStyle(ColorTokens.Text.tertiary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(server.name)
                    .font(TypographyTokens.standard)
                    .lineLimit(1)
                if server.serverName != server.name {
                    Text(server.serverName)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if !server.description.isEmpty {
                Text(server.description)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    // MARK: - Tree Structure

    private struct FlatTreeItem {
        let id: String
        let depth: Int
        let kind: FlatTreeItemKind
    }

    private enum FlatTreeItemKind {
        case group(SQLServerCMSGroup)
        case server(SQLServerCMSServer)
    }

    private func buildFlatTree() -> [FlatTreeItem] {
        var result: [FlatTreeItem] = []
        let rootGroups = groups.filter(\.isRoot)
        for group in rootGroups {
            appendGroup(group, depth: 0, to: &result)
        }
        let groupIDs = Set(groups.map(\.groupId))
        for server in servers where !groupIDs.contains(server.groupId) {
            result.append(FlatTreeItem(id: "srv-\(server.serverId)", depth: 0, kind: .server(server)))
        }
        return result
    }

    private func appendGroup(_ group: SQLServerCMSGroup, depth: Int, to result: inout [FlatTreeItem]) {
        result.append(FlatTreeItem(id: "grp-\(group.groupId)", depth: depth, kind: .group(group)))
        for child in groups where child.parentId == group.groupId {
            appendGroup(child, depth: depth + 1, to: &result)
        }
        for server in servers where server.groupId == group.groupId {
            result.append(FlatTreeItem(id: "srv-\(server.serverId)", depth: depth + 1, kind: .server(server)))
        }
    }

    // MARK: - Data Loading

    func loadData() async {
        guard let mssql = session.session as? MSSQLSession else {
            errorMessage = "Not a SQL Server connection."
            isLoading = false
            return
        }
        do {
            groups = try await mssql.cms.listGroups()
            servers = try await mssql.cms.listServers()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
