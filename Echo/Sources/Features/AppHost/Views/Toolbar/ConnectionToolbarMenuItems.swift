import SwiftUI
import EchoSense

struct ConnectionToolbarMenuItems: View {
    let parentID: UUID?
    let currentConnectionID: UUID?
    let onConnect: (SavedConnection) async -> Void
    
    @Environment(ConnectionStore.self) private var connectionStore

    var body: some View {
        let folders = connectionStore.folders
            .filter { $0.kind == .connections && $0.parentFolderID == parentID }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        let connections = connectionStore.connections
            .filter { $0.folderID == parentID }
            .sorted { displayName(for: $0).localizedCaseInsensitiveCompare(displayName(for: $1)) == .orderedAscending }

        ForEach(folders, id: \.id) { folder in
            Menu {
                ConnectionToolbarMenuItems(
                    parentID: folder.id,
                    currentConnectionID: currentConnectionID,
                    onConnect: onConnect
                )
            } label: {
                HStack(spacing: SpacingTokens.xs) {
                    Image(systemName: "folder")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                    Text(folder.name)
                        .font(TypographyTokens.standard.weight(.regular))
                }
            }
        }

        ForEach(connections, id: \.id) { connection in
            Button {
                Task {
                    await onConnect(connection)
                }
            } label: {
                HStack(spacing: SpacingTokens.xs) {
                    let icon = connectionIcon(for: connection)
                    icon.image
                        .renderingMode(icon.isTemplate ? .template : .original)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                        .cornerRadius(icon.isTemplate ? 0 : 3)
                    
                    Text(displayName(for: connection))
                        .font(TypographyTokens.standard.weight(.regular))
                    Spacer()
                    if currentConnectionID == connection.id {
                        Image(systemName: "checkmark")
                            .font(TypographyTokens.caption2.weight(.semibold))
                    }
                }
            }
        }
    }
    
    private func displayName(for connection: SavedConnection) -> String {
        let trimmed = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        let hostTrimmed = connection.host.trimmingCharacters(in: .whitespacesAndNewlines)
        return hostTrimmed.isEmpty ? "Untitled Connection" : hostTrimmed
    }
    
    private func connectionIcon(for connection: SavedConnection) -> ToolbarIcon {
        let assetName = connection.databaseType.iconName
        if hasImage(named: assetName) {
            return .asset(assetName, isTemplate: false)
        }
        return .system("externaldrive")
    }
    
    private func hasImage(named name: String) -> Bool {
        #if canImport(AppKit)
        return NSImage(named: name) != nil
        #elseif canImport(UIKit)
        return UIImage(named: name) != nil
        #else
        return false
        #endif
    }
}
