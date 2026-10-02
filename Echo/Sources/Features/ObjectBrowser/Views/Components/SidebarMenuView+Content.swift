import SwiftUI

extension SidebarMenu {
    @ViewBuilder
    func contentView(for section: NavSection) -> some View {
        switch section {
        case .folder:
            // Rendered separately by `SidebarMenu` so it stays alive while other tools show.
            EmptyView()
        case .bookmark, .clipboard, .snippets, .history:
            EmptyView() // Removed rail destinations; library lives in the inspector (round 39).
        case .connections:
            EmptyView() // Round MC: connections are managed in Manage Connections; this sidebar had folders.
        }
    }
}
