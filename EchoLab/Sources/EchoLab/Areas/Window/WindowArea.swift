import SwiftUI

/// The window as it is in Echo today: a canvas with the server rail, opaque cards, and glass
/// only on controls (decisions 2026-09-29, review rounds 3 to 9).
@MainActor
enum WindowArea {
    static let area = LabArea(
        id: "window",
        title: "Window and cards",
        symbol: "macwindow",
        summary: "A canvas holding the server rail, the tree, and opaque cards. Glass is only for controls.",
        asBuilt: AsBuiltPage(
            verification: .init(
                level: .code, commit: "d359a536", date: "2026-09-30",
                note: "Read from WorkspaceShell, ServerRail, ServerRailEntry, ServerRailMonogram, WorkspaceWelcomeView, ConnectionDashboardView and the workspace, rail and welcome tokens. The specimen is the Echo Labs rail (servers and the tool pill) with a stand-in tree and two cards."),
            stageHeight: 520,
            behaviours: [
                .init(trigger: "Click a server in the rail", result: "With the tree showing, the tree glides to that server and the rail keeps it selected while it does. While you scroll, the rail marks the server whose card is at the top."),
                .init(trigger: "Click a server with the tree hidden", result: "A plain click peeks: the tree slides back out on glass over the cards, without moving them. A click on the cards, Esc, opening a tab or showing the tree puts it away; a plain click on the server that is peeking does too. ⌘-click or double-click shows the tree for good. The Collapsed Server Click setting changes this: peek and ⌘-click (default), always peek, or always show the tree."),
                .init(trigger: "Server connecting", result: "Its monogram breathes until it connects; with Reduce Motion it stays still and dimmed."),
                .init(trigger: "Connection lost", result: "The monogram dims to 40%; the tooltip says why."),
                .init(trigger: "Hover a server", result: "The monogram turns primary; the tooltip shows the name and host, and a line for connecting, lost, or how many queries are running. Running queries show nothing else in the rail."),
                .init(trigger: "Click +", result: "Opens the connections menu (open sessions, saved connections by folder, Manage Connections, Quick Connect); it is never selected."),
                .init(trigger: "Click a tool at the bottom of the rail", result: "Its page (Bookmarks, Snippets, History, Clipboard) shows in the tree's place, and the tree opens if hidden. The tool that is showing is filled in the accent colour; clicking it again goes back to the tree."),
                .init(trigger: "⌃⌘S or the sidebar button", result: "Hides and shows the tree. The button says Hide Sidebar or Show Sidebar (⌃⌘S) and is disabled, with a reason, while there is nothing to show."),
                .init(trigger: "No server and no tab", result: "The welcome sits on the canvas with no card: Echo's icon and name; Connect… (glass, prominent), Quick Connect and Manage (glass); then Recent, the latest five connections on one small card, each with its monogram in its colour, name, host and how long ago."),
                .init(trigger: "Server active, no tab", result: "The server page on the canvas: the name large, its version as one quiet line, its tools on glass buttons (New Query first), and a databases card with a filter. Its top lines up with the rail's."),
                .init(trigger: "Nothing to show in the tree", result: "The tree stays hidden and ⌃⌘S does nothing until a server connects or you pick a tool."),
            ],
            motions: [
                .init(name: "Rail selection", curve: "liquid stretch: the leading edge races, the trailing edge follows", duration: "0.28s and 0.55s", note: "echoMotion.liquidLead and liquidTrail"),
                .init(name: "Server pill grows and shrinks", curve: "house spring", duration: "0.45s", note: "a server scales in from 40%"),
                .init(name: "Hide the tree", curve: "smooth, no overshoot", duration: "0.45s", note: "echoMotion.settle; the tree slides left behind the rail"),
                .init(name: "Show the tree", curve: "house spring", duration: "0.45s"),
                .init(name: "Connecting monogram", curve: "ease in-out, opacity and a small dip in size", duration: "0.7s half cycle", note: "echoMotion.pulseHalfPeriod; minimum opacity 15%"),
                .init(name: "Peek", curve: "house spring", duration: "0.45s"),
                .init(name: "Monogram hover and select", curve: "hover and press curves", duration: "0.12s and 0.16s"),
            ],
            measurements: [
                .init(label: "Card corners", value: "16pt (setting: 10 to 26)", token: "LayoutTokens.Workspace.cardCornerRadius"),
                .init(label: "Card edge", value: "0.5pt, 35% separator", token: "cardEdgeWidth / cardEdgeOpacity"),
                .init(label: "Card shadow", value: "black 12%, blur 10, y 4", token: "ShadowTokens.workspaceCard"),
                .init(label: "Rail item", value: "28 · 34 (default) · 40pt, a setting", token: "RailItemSize.points"),
                .init(label: "Monogram", value: "37% of the item: 12.5pt at 34pt, rounded design; bold when selected", token: "LayoutTokens.Rail.monogramFontRatio"),
                .init(label: "Rail pill padding", value: "4pt", token: "LayoutTokens.Rail.pillPadding"),
                .init(label: "Selection disc", value: "the item minus 3pt on every side, filled with the text background, shadow black 16% radius 1.5 y 0.5", token: "ColorTokens.Workspace.railSelection / ShadowTokens.railSelection / LayoutTokens.Rail.selectionInset"),
                .init(label: "Tool symbols", value: "13pt; filled in the accent colour when its page shows", token: "LayoutTokens.Rail.toolSymbolSize"),
                .init(label: "Peek card", value: "glass, 18pt corners", token: "LayoutTokens.FloatingSurface.cornerRadius"),
                .init(label: "Welcome", value: "420pt wide, icon 32pt, title 26pt bold, recents on a card with 28pt rows", token: "LayoutTokens.Welcome"),
                .init(label: "Server page", value: "600pt wide, name 26pt bold", token: "LayoutTokens.ServerPage"),
                .init(label: "Tool button height", value: "30pt", token: "LayoutTokens.Rail.toolHeight"),
                .init(label: "Tree width", value: "260pt ideal, 200 to 480", token: "LayoutTokens.Workspace.treeIdealWidth / Min / Max"),
                .init(label: "Gap between panes", value: "4, 6 or 8pt (setting)", token: "Spacing Between Panes"),
            ],
            rules: [
                .init(text: "Cards are opaque, and glass never goes on them",
                      why: "The tree and editor are content. Glass over a flat canvas has nothing to refract and reads as a grey box.",
                      rounds: ["decided.window-canvas-and-cards"]),
                .init(text: "Card corners are 16pt",
                      why: "The macOS 27 window corner, measured from a screenshot; a Card Corners setting offers 10 to 26.",
                      rounds: ["decided.window-canvas-and-cards"]),
                .init(text: "A + ends the server pill",
                      why: "With one server the pill held a single item and read as a double border; connecting from the rail is also closer to the servers.",
                      rounds: ["decided.rail-servers"]),
                .init(text: "The selection disc is inset 3pt",
                      why: "So a single server never looks like a pill inside a pill.",
                      rounds: ["decided.rail-servers"]),
                .init(text: "Identity is a two-letter monogram in the server's colour",
                      why: "Colour dots and engine badges were rejected; the selected monogram takes its server's colour.",
                      rounds: ["decided.rail-servers"]),
                .init(text: "Welcome and server pages sit on the canvas, no card",
                      why: "Cards are only for content.",
                      rounds: ["decided.window-canvas-and-cards"]),
            ],
            code: [
                "Echo/Sources/Features/AppHost/Views/Navigation/WorkspaceShell.swift",
                "Echo/Sources/Features/ObjectBrowser/Views/Components/ServerRail.swift",
                "Echo/Sources/Features/AppHost/Views/Tabs/WorkspaceContainer/WorkspaceWelcomeView.swift",
                "Echo/Sources/Features/AppHost/Views/Tabs/EditorContainer/ConnectionDashboard/ConnectionDashboardView.swift",
                "Echo/Sources/Shared/DesignSystem/Components/WorkspaceCard.swift",
                "Packages/EchoDesignSystem/Sources/EchoDesignSystem/Tokens/LayoutToken.swift",
            ]
        ) {
            WindowSpecimen()
        },
        spec: WindowSpec.spec()
    )
}

struct WindowSpecimen: View {
    @State private var selected: String? = LabServer.samples.first?.id
    @Environment(\.workspaceCardCornerRadius) private var corner

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.sm) {
            LabRailView(servers: LabServer.samples, selectedID: $selected, selection: .liquid, identity: .colorOnSelection)
                .specAnchor("2.1")
            LabRound14TreeStub().frame(width: 220).specAnchor("3.1")
            VStack(spacing: SpacingTokens.sm) {
                card("Editor").specAnchor("1.3")
                card("Results").specAnchor("1.4")
            }
        }
        .padding(SpacingTokens.lg)
    }

    private func card(_ title: String) -> some View {
        Text(title).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .workspaceCard()
    }
}
