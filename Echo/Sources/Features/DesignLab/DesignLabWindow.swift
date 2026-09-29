#if DEBUG
import SwiftUI

/// Debug-only window that hosts every Design Lab playground inside the running app, so the lab
/// works even when Xcode's canvas can't launch Echo in time. Open it from Help › Design Lab.
struct DesignLabWindow: Scene {
    static let sceneID = "design-lab"

    var body: some Scene {
        Window("Design Lab", id: Self.sceneID) {
            DesignLabRootView()
        }
        .defaultSize(width: 1400, height: 900)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)
    }
}

struct DesignLabCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .help) {
            Button {
                openWindow(id: DesignLabWindow.sceneID)
            } label: {
                Label("Design Lab", systemImage: "paintpalette")
            }
        }
    }
}

private enum DesignLabPage: String, CaseIterable, Identifiable {
    case window = "Window · canvas and cards"
    case rail = "Server rail"
    case tree = "Tree · sticky header"
    case results = "Results grid"
    case floating = "Toasts and notifications"
    case inspector = "Inspector"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .window: "macwindow"
        case .rail: "circle.grid.3x3"
        case .tree: "list.bullet.indent"
        case .results: "tablecells"
        case .floating: "bell"
        case .inspector: "sidebar.right"
        }
    }
}

private struct DesignLabRootView: View {
    @State private var page: DesignLabPage? = .window

    var body: some View {
        NavigationSplitView {
            List(selection: $page) {
                ForEach(DesignLabPage.allCases) { page in
                    Label(page.rawValue, systemImage: page.symbol).tag(page)
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            ScrollView([.horizontal, .vertical]) {
                detail.padding(20)
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch page ?? .window {
        case .window: LabWindowPlayground()
        case .rail: LabRailPlayground()
        case .tree: LabTreePlayground()
        case .results: LabResultsPlayground()
        case .floating: LabFloatingPlayground()
        case .inspector: LabInspectorPlayground()
        }
    }
}
#endif
