import SwiftUI
import EchoSense

enum ExplorerSidebarConstants {
    static let scrollCoordinateSpace = "ExplorerSidebarScrollSpace"
    static let objectsTopAnchor = "ExplorerSidebarObjectsTop"
    static let connectedServersAnchor = "ExplorerSidebarConnectedServers"
    static let scrollBottomPadding: CGFloat = 32
    static let bottomControlHeight: CGFloat = 20
}

struct ExplorerCreationMenuItem: Hashable {
    enum Icon: Hashable {
        case system(String)
        case asset(String)
    }

    let title: String
    let icon: Icon

    @ViewBuilder
    func iconView(accentColor: Color) -> some View {
        switch icon {
        case .system(let name):
            Image(systemName: name)
                .font(TypographyTokens.standard.weight(.semibold))
                .foregroundStyle(accentColor)
        case .asset(let name):
            Image(name)
                .renderingMode(.template)
                .resizable()
                .frame(width: 12, height: 12)
                .foregroundStyle(accentColor)
        }
    }
}
