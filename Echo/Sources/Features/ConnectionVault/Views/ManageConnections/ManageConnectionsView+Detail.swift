@preconcurrency import SwiftUI
import AppKit

extension ManageConnectionsView {
    var detailContent: some View {
        detailBody
            .accentColor(appearanceStore.accentColor)
            .navigationTitle(navigationTitleText)
            .navigationSubtitle(navigationSubtitleText)
            .toolbar {
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
        if case .folder(let folderID, _) = sidebarSelection,
           let folder = folder(withID: folderID) {
            if let desc = folder.folderDescription, !desc.isEmpty {
                return desc
            }
            return activeSection.title
        }
        return ""
    }

    @ViewBuilder
    var addToolbarMenu: some View {
        Menu {
            Button {
                handlePrimaryAdd(for: .connections)
            } label: {
                Label("New Connection", systemImage: "externaldrive.badge.plus")
            }
            Button {
                createNewIdentity()
            } label: {
                Label("New Identity", systemImage: "person.crop.circle.badge.plus")
            }
            Divider()
            Button {
                presentCreateFolder(for: activeSection)
            } label: {
                Label("New Folder", systemImage: "folder.badge.plus")
            }
        } label: {
            Label("Add", systemImage: "plus")
        }
        .menuIndicator(.hidden)
        .help("Add connection, identity, or folder")
    }
}
