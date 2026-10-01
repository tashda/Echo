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
                level: .code, commit: "b113aaa2", date: "2026-10-01",
                note: "Read from WorkspaceShell, ServerRail, ServerRailEntry, ServerRailMonogram, WorkspaceWelcomeView, ConnectionDashboardView and the workspace, rail and welcome tokens. The specimen is the Echo Labs server rail (tool pill removed in round 39) with a stand-in tree and two cards. Checked b5eebdb9 and fb789c41: only footer-blur tokens changed; no window measurements changed. 2026-10-01: checked the commits since ef1c3bba (round 32.2's dark canvas, card edges and shadows; round 30.1's always-coloured monogram; round 34's Refresh); the LayoutToken changes in that range are the editor's and results'."),
            stageHeight: 520,
            behaviours: [
                .init(trigger: "Click a server in the rail", result: "With the tree showing, the tree glides to that server and the rail keeps it selected while it does. While you scroll, the rail marks the server whose card is at the top."),
                .init(trigger: "Click a server with the tree hidden", result: "The tree opens and, as it slides in, scrolls to that server; the rail's disc shows which one (round 40). The glass peek and its setting are gone."),
                .init(trigger: "Refresh in the toolbar", result: "Only while the front tab can reload (tool tabs; never a query tab). It shows only its own reload: a spinner, then ✓ or ✗. ⌘R (View › Reload Tab) does the same (round 34)."),
                .init(trigger: "Server connecting", result: "Its monogram breathes until it connects; with Reduce Motion it stays still and dimmed."),
                .init(trigger: "Connection lost", result: "The monogram dims to 40%; the tooltip says why."),
                .init(trigger: "Hover a server", result: "The monogram turns primary; the tooltip shows the name and host, and a line for connecting, lost, or how many queries are running. Running queries show nothing else in the rail."),
                .init(trigger: "Click +", result: "Opens the connections menu (open sessions, saved connections by folder, Manage Connections, Quick Connect); it is never selected."),
                .init(trigger: "View › Bookmarks or Query History (or inspector menu)", result: "Opens that library in the inspector column, beside the tab; the tree stays as it is. Details, Bookmarks and History share a segmented picker. The rail tool pill, Snippets and Echo clipboard history are removed (round 39; awaiting build/run verification)."),
                .init(trigger: "⌃⌘S or the sidebar button", result: "Hides and shows the tree. The button says Hide Sidebar or Show Sidebar (⌃⌘S) and is disabled, with a reason, while there is nothing to show."),
                .init(trigger: "No server and no tab", result: "The welcome sits on the canvas with no card: Echo's mark alone, which echoes in each time the welcome appears, then Connect… (glass, prominent), Quick Connect and Manage (glass); then Recent, the latest five connections on one small card, each with its monogram in its colour, name, host and how long ago. The buttons and the recents rise in after the mark (round 48)."),
                .init(trigger: "Server active, no tab", result: "The server page on the canvas: the name large, its version as one quiet line, its tools on glass buttons (New Query first), and a databases card with a filter. Its top lines up with the rail's. It builds up when it appears: the name, the version, the tools and the databases rise 8pt and fade in, 0.06 s apart (round 48)."),
                .init(trigger: "A server connects from the welcome", result: "The pills echo out to the left, last first (0.46 s) and the buttons fade. Then the server grows into the rail, the tree slides out 0.12 s later and the server page builds up. If the connection fails the welcome comes back and echoes in again (round 48, LV2, CO1, AR2)."),
                .init(trigger: "Close the last tab", result: "The server stays active, so the canvas shows its page. The page is mounted under the tabs; the card fades and settles to 98.5% over 0.28 s and shows it (round 48, CW1, CH1). Opening a tab is unchanged: the card fades in from 98% on the house spring."),
                .init(trigger: "Nothing to show in the tree", result: "The tree stays hidden and ⌃⌘S does nothing until a server connects."),
                .init(trigger: "While the tree, inspector, tab overview or an Explorer switch animates, and while the Explorer tree scrolls", result: "The window can't be dragged for those few hundred milliseconds (WindowDragPause). Otherwise AppKit recomputed the window's drag regions on every frame, walking the whole window's focus order."),
            ],
            motions: [
                .init(name: "Rail selection", curve: "liquid stretch: the leading edge races, the trailing edge follows", duration: "0.28s and 0.55s", note: "echoMotion.liquidLead and liquidTrail"),
                .init(name: "Server pill grows and shrinks", curve: "house spring", duration: "0.45s", note: "a server scales in from 40%"),
                .init(name: "Hide the tree", curve: "smooth, no overshoot", duration: "0.45s", note: "echoMotion.settle; the tree slides left behind the rail"),
                .init(name: "Show the tree", curve: "house spring", duration: "0.45s"),
                .init(name: "Connecting monogram", curve: "ease in-out, opacity and a small dip in size", duration: "0.7s half cycle", note: "echoMotion.pulseHalfPeriod; minimum opacity 15%"),
                .init(name: "Welcome mark echoes in", curve: "cubic-bezier(0.3, 1.3, 0.5, 1): overshoots, from 110 of the mark's 568 units to the left", duration: "0.9s per pill, 0.12s apart, starting 0.25s after the welcome appears", note: "WelcomeMarkMotion, echodb.dev's Mark.astro"),
                .init(name: "Welcome rises in", curve: "smooth, 10pt up", duration: "0.45s, buttons 0.55s after the mark starts, recents 0.15s later"),
                .init(name: "Welcome leaves on connect", curve: "ease, to the left, last pill first", duration: "0.34s per pill, 0.06s apart; the rail follows at 0.52s and the tree 0.12s after it"),
                .init(name: "Server page builds up", curve: "smooth, 8pt up", duration: "0.35s per piece, 0.06s apart, starting 0.15s after it appears"),
                .init(name: "Closing the last tab", curve: "ease out, fade and scale to 98.5%", duration: "0.28s"),
                .init(name: "Monogram hover and select", curve: "hover and press curves", duration: "0.12s and 0.16s"),
            ],
            measurements: [
                .init(label: "Card corners", value: "16pt (setting: 10 to 26)", token: "LayoutTokens.Workspace.cardCornerRadius"),
                .init(label: "Card edge", value: "0.5pt at 35%: the separator in light, white 20% (a 7% hairline) in dark, plus a lit top edge in dark (primary 10% fading by the middle, 1pt); Increase Contrast: a solid 1pt separator", token: "cardEdgeWidth / cardEdgeOpacity / ColorTokens.Workspace.cardEdge"),
                .init(label: "Card shadow", value: "light: black 12%, blur 10, y 4; dark: a contact shadow (black 60%, blur 3, y 1) over an ambient one (black 40%, blur 24, y 10)", token: "ShadowTokens.workspaceCard / workspaceCardContact / workspaceCardAmbient"),
                .init(label: "Canvas", value: "light: the window background; dark: white 9.5%, just under the cards", token: "ColorTokens.Workspace.canvas"),
                .init(label: "Rail item", value: "28 · 34 (default) · 40pt, a setting", token: "RailItemSize.points"),
                .init(label: "Monogram", value: "37% of the item: 12.5pt at 34pt, rounded design; bold when selected", token: "LayoutTokens.Rail.monogramFontRatio"),
                .init(label: "Rail pill padding", value: "4pt", token: "LayoutTokens.Rail.pillPadding"),
                .init(label: "Selection disc", value: "the item minus 3pt on every side, filled with the text background, shadow black 16% radius 1.5 y 0.5", token: "ColorTokens.Workspace.railSelection / ShadowTokens.railSelection / LayoutTokens.Rail.selectionInset"),
                .init(label: "Welcome", value: "420pt wide, mark 120pt wide (no name), recents on a card with 28pt rows", token: "LayoutTokens.Welcome"),
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
                .init(text: "A control signals only what it did",
                      why: "After a query Run and Refresh both showed ✓; Refresh now shows only its own reload, and long operations show on the bell.",
                      rounds: ["ongoing.refresh-and-activity-r34"]),
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
                "Echo/Sources/Features/AppHost/Views/Toolbar/RefreshToolbarButton/TabReloader.swift",
                "Echo/Sources/Features/ObjectBrowser/Views/Components/ServerRail.swift",
                "Echo/Sources/Features/ObjectBrowser/Views/Components/ServerRail+Components.swift",
                "Echo/Sources/Features/ObjectBrowser/Views/Components/ServerRail+Selection.swift",
                "Echo/Sources/Features/AppHost/Views/Navigation/WorkspaceRailColumn.swift",
                "Echo/Sources/Features/AppHost/Views/Navigation/WorkspaceInspectorColumn.swift",
                "Echo/Sources/Features/AppHost/Views/Tabs/WorkspaceContainer/WorkspaceWelcomeView.swift",
                "Echo/Sources/Features/AppHost/Views/Tabs/WorkspaceContainer/WelcomeMarkMotion.swift",
                "Echo/Sources/Features/AppHost/Views/Navigation/WorkspaceShell+WelcomeDeparture.swift",
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
            WindowRailSpecimen(selected: $selected)
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
