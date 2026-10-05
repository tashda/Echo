import SwiftUI
#if os(macOS)
import AppKit
#endif

/// The tab's home (round IC, H1). The mark itself is on the strip's icon layer (`TabIconLayer`),
/// so the tab's measured width never changes with it (round 49); the tab adds the home's commands
/// to its menu.
extension QueryTabButton {
    /// Save, Save to Bookmarks…, Save to File…; then Show and Detach for a tab with that home.
    @ViewBuilder
    var homeMenuContent: some View {
        Button {
            environmentState.saveTab(tab)
        } label: {
            Label("Save", systemImage: "square.and.arrow.down")
        }

        Button {
            environmentState.presentSaveCard(for: tab, destination: .bookmarks)
        } label: {
            Label("Save to Bookmarks…", systemImage: "bookmark")
        }

        Button {
            environmentState.presentSaveCard(for: tab, destination: .file)
        } label: {
            Label("Save to File…", systemImage: "doc")
        }

        if let context = tab.bookmarkContext {
            Divider()
            Button {
                appState.revealBookmark(context.bookmarkID)
            } label: {
                Label("Show in Bookmarks", systemImage: "sidebar.right")
            }
            Button {
                tab.detachFromHome()
            } label: {
                Label("Detach from Bookmark", systemImage: "bookmark.slash")
            }
        } else if let url = tab.fileURL {
            Divider()
#if os(macOS)
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } label: {
                Label("Show in Finder", systemImage: "folder")
            }
#endif
            Button {
                tab.detachFromHome()
            } label: {
                Label("Detach from File", systemImage: "doc.badge.ellipsis")
            }
        }
    }
}
