import SwiftUI

#if os(macOS)
import AppKit

// MARK: - SwiftUI Content

struct ConnectionsPopoverContent: View {
    let connectionStore: ConnectionStore
    let environmentState: EnvironmentState
    let dismiss: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                if !recentConnections.isEmpty {
                    sectionHeader("Recent")
                    ForEach(recentConnections) { conn in
                        PopoverConnectionRow(
                            connection: conn,
                            isSelected: conn.id == connectionStore.selectedConnectionID,
                            icon: iconImage(for: conn),
                            displayName: displayName(for: conn)
                        ) {
                            Task { await environmentState.connect(to: conn) }
                            dismiss()
                        }
                    }
                    divider
                }

                ForEach(folderSections, id: \.folder.id) { section in
                    sectionHeader(section.folder.name)
                    ForEach(section.connections) { conn in
                        PopoverConnectionRow(
                            connection: conn,
                            isSelected: conn.id == connectionStore.selectedConnectionID,
                            icon: iconImage(for: conn),
                            displayName: displayName(for: conn)
                        ) {
                            Task { await environmentState.connect(to: conn) }
                            dismiss()
                        }
                    }
                }

                if !unfiledConnections.isEmpty {
                    if !folderSections.isEmpty {
                        sectionHeader("Other")
                    }
                    ForEach(unfiledConnections) { conn in
                        PopoverConnectionRow(
                            connection: conn,
                            isSelected: conn.id == connectionStore.selectedConnectionID,
                            icon: iconImage(for: conn),
                            displayName: displayName(for: conn)
                        ) {
                            Task { await environmentState.connect(to: conn) }
                            dismiss()
                        }
                    }
                }

                divider

                PopoverActionRow(title: "Manage Connections\u{2026}") {
                    ManageConnectionsWindowController.shared.present()
                    dismiss()
                }
                PopoverActionRow(title: "Quick Connect\u{2026}") {
                    AppDirector.shared.appState.showSheet(.quickConnect)
                    dismiss()
                }
            }
            .padding(.vertical, SpacingTokens.xxs)
        }
        .frame(width: 260, height: 360)
    }

    // MARK: - Data

    private var projectID: UUID? {
        AppDirector.shared.projectStore.selectedProject?.id
    }

    private var recentConnections: [SavedConnection] {
        let records = Array(environmentState.recentConnections.prefix(3))
        return records.compactMap { record in
            connectionStore.connections.first { $0.id == record.id }
        }
    }

    private var folderSections: [PopoverFolderSection] {
        let folders = connectionStore.folders
            .filter { $0.kind == .connections && $0.parentFolderID == nil && $0.projectID == projectID }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return folders.compactMap { folder in
            let conns = connectionStore.connections
                .filter { $0.folderID == folder.id && $0.projectID == projectID }
                .sorted { displayName(for: $0).localizedCaseInsensitiveCompare(displayName(for: $1)) == .orderedAscending }
            guard !conns.isEmpty else { return nil }
            return PopoverFolderSection(folder: folder, connections: conns)
        }
    }

    private var unfiledConnections: [SavedConnection] {
        connectionStore.connections
            .filter { $0.folderID == nil && $0.projectID == projectID }
            .sorted { displayName(for: $0).localizedCaseInsensitiveCompare(displayName(for: $1)) == .orderedAscending }
    }

    // MARK: - Views

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(TypographyTokens.detail.weight(.medium))
            .foregroundStyle(ColorTokens.Text.secondary)
            .padding(.horizontal, 14)
            .padding(.top, SpacingTokens.xxs)
            .padding(.bottom, 2)
    }

    private var divider: some View {
        Divider()
            .padding(.horizontal, 10)
            .padding(.vertical, SpacingTokens.xxs2)
    }

    private func iconImage(for connection: SavedConnection) -> NSImage? {
        NSImage(named: connection.databaseType.iconName)
    }

    private func displayName(for connection: SavedConnection) -> String {
        let trimmed = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? connection.host : trimmed
    }
}

// MARK: - Row Views (each tracks its own hover state independently)

private struct PopoverConnectionRow: View {
    let connection: SavedConnection
    let isSelected: Bool
    let icon: NSImage?
    let displayName: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.xxs2) {
                Image(systemName: "checkmark")
                    .font(TypographyTokens.compact.weight(.bold))
                    .frame(width: 14)
                    .opacity(isSelected ? 1 : 0)

                if let icon {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "server.rack")
                        .font(TypographyTokens.caption2)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .frame(width: 16, height: 16)
                }

                Text(displayName)
                    .font(TypographyTokens.standard)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, SpacingTokens.xxs2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isHovered ? ColorTokens.accent : .clear)
                    .padding(.horizontal, SpacingTokens.xxs2)
            )
            .foregroundStyle(isHovered ? .white : .primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct PopoverActionRow: View {
    let title: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(TypographyTokens.standard)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, SpacingTokens.xxs2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isHovered ? ColorTokens.accent : .clear)
                    .padding(.horizontal, SpacingTokens.xxs2)
            )
            .foregroundStyle(isHovered ? .white : .primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Models

private struct PopoverFolderSection {
    let folder: SavedFolder
    let connections: [SavedConnection]
}
#endif
