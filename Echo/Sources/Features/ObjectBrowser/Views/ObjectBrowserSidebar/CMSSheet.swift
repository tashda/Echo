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
        VStack(spacing: 0) {
            headerBar
            Divider()

            if isLoading {
                VStack { Spacer(); ProgressView("Loading CMS data\u{2026}"); Spacer() }
            } else if let error = errorMessage {
                VStack {
                    Spacer()
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(ColorTokens.Text.secondary)
                    Spacer()
                }
                .padding()
            } else {
                contentView
            }

            Divider()
            footerBar
        }
        .frame(minWidth: 480, minHeight: 340)
        .frame(idealWidth: 540, idealHeight: 400)
        .task { await loadData() }
    }

    private var headerBar: some View {
        HStack {
            Image(systemName: "server.rack")
                .foregroundStyle(ColorTokens.accent)
            Text("Central Management Servers")
                .font(TypographyTokens.prominent.weight(.semibold))
            Spacer()
        }
        .padding(SpacingTokens.md)
    }

    private var footerBar: some View {
        HStack {
            Spacer()
            Button("Done") { onDismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(SpacingTokens.md)
    }

    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                if groups.isEmpty && servers.isEmpty {
                    emptyState
                } else {
                    treeContent
                }
            }
            .padding(SpacingTokens.md)
        }
    }

    private var emptyState: some View {
        VStack(spacing: SpacingTokens.sm) {
            Image(systemName: "server.rack").font(.largeTitle).foregroundStyle(ColorTokens.Text.quaternary)
            Text("No CMS groups or servers registered.").font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.tertiary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, SpacingTokens.xl)
    }

    @ViewBuilder
    private var treeContent: some View {
        let flatItems = buildFlatTree()
        ForEach(flatItems, id: \.id) { item in
            switch item.kind {
            case .group(let group):
                groupRow(group)
                    .padding(.leading, CGFloat(item.depth) * SpacingTokens.md)
            case .server(let server):
                serverRow(server)
                    .padding(.leading, CGFloat(item.depth) * SpacingTokens.md)
            }
        }
    }

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
        // Ungrouped servers
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

    private func groupRow(_ group: SQLServerCMSGroup) -> some View {
        HStack(spacing: SpacingTokens.sm) {
            Image(systemName: "folder")
                .foregroundStyle(ColorTokens.accent)
            Text(group.name)
                .font(TypographyTokens.standard.weight(.medium))
            if !group.description.isEmpty {
                Text(group.description)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(SpacingTokens.xs)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(ColorTokens.Background.secondary)
        )
    }

    private func serverRow(_ server: SQLServerCMSServer) -> some View {
        HStack(spacing: SpacingTokens.sm) {
            Image(systemName: "desktopcomputer")
                .foregroundStyle(ColorTokens.Text.tertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text(server.name)
                    .font(TypographyTokens.standard)
                if server.serverName != server.name {
                    Text(server.serverName)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            Spacer()
            if !server.description.isEmpty {
                Text(server.description)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(SpacingTokens.xs)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(ColorTokens.Background.secondary)
        )
    }

    func loadData() async {
        guard let mssql = session.session as? MSSQLSession else {
            errorMessage = "Not a SQL Server connection."
            isLoading = false
            return
        }
        do {
            async let g = mssql.cms.listGroups()
            async let s = mssql.cms.listServers()
            groups = try await g
            servers = try await s
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
