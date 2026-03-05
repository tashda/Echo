@preconcurrency import SwiftUI
import AppKit

extension ManageConnectionsView {
    var detailContent: some View {
        detailBody
            .background(ColorTokens.Background.secondary)
            .accentColor(appearanceStore.accentColor)
            .searchable(
                text: $searchText,
                placement: .toolbar,
                prompt: Text(activeSection.searchPlaceholder)
            )
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ToolbarTitleWithSubtitle(
                        title: navigationTitleText,
                        subtitle: navigationSubtitleText
                    )
                }
                ToolbarItem(placement: .primaryAction) {
                    addToolbarMenu
                }
            }
    }

    var navigationTitleText: String {
        if case .folder(let folderID, _) = sidebarSelection,
           let folder = folder(withID: folderID) {
            return folder.displayName
        }
        return activeSection.title
    }

    var navigationSubtitleText: String {
        if case .folder(_, _) = sidebarSelection {
            return activeSection.title
        }
        return ""
    }

    @ViewBuilder
    var addToolbarMenu: some View {
        Menu {
            switch activeSection {
            case .connections:
                Button {
                    handlePrimaryAdd(for: .connections)
                } label: {
                    Label("New Connection", systemImage: "externaldrive.badge.plus")
                }
                Button {
                    presentCreateFolder(for: .connections)
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
            case .identities:
                Button {
                    handlePrimaryAdd(for: .identities)
                } label: {
                    Label("New Identity", systemImage: "person.crop.circle.badge.plus")
                }
                Button {
                    presentCreateFolder(for: .identities)
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
            }
        } label: {
            ToolbarAddButton()
        }
        .menuIndicator(.hidden)
        .menuStyle(.borderlessButton)
        .controlSize(.large)
        .help(activeSection == .connections ? "Add connection or folder" : "Add identity or folder")
    }
}
