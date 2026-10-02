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
                level: .code, commit: "f505b760", date: "2026-10-02",
                note: "Read from WorkspaceShell, ServerRail, ServerRailEntry, ServerRailMonogram, WorkspaceWelcomeView, ConnectionDashboardView and the workspace, rail and welcome tokens. The specimen is the Echo Labs server rail (tool pill removed in round 39) with a stand-in tree and two cards. Checked b5eebdb9 and fb789c41: only footer-blur tokens changed; no window measurements changed. 2026-10-01: checked the commits since ef1c3bba (round 32.2's dark canvas, card edges and shadows; round 30.1's always-coloured monogram; round 34's Refresh); the LayoutToken changes in that range are the editor's and results'. 2026-10-02: checked 4db9915a (the results' soft side edges: nothing here); round 52 built (the opened connection trail); the specimen still shows the closed trail only. 2026-10-02: round 51 built (name bubble, own symbol or emoji, Customize Appearance); the specimen does not show them yet. 2026-10-02: round 55 built (no ring, a hairline between open and minimized servers, the recents pill, the server rack circle in place of the +, Settings › Appearance › Server Trail): read from ServerRail, ServerRail+Components, ServerRail+Recents, ServerRail+Layout, ServerRailLayout and the Rail tokens. 2026-10-02: owner feedback on round 55 built (name bubble and context menu on recents, a bright connect glyph, the trail closes on an outside click, smoother glide: one glass container, no item transitions, no scroll view while the pill fits): read from ServerRail, ServerRail+Components, ServerRail+Recents, ServerRail+RecentsMenu, ServerRail+Appearance, ConnectTrailOutsideClick. 2026-10-02: round 56 built (the connect card is a drawer beside the trail; the circle turns to an ×; the pills stay usable): read from ServerRail, ServerRail+ConnectTrail, ServerRail+Recents, ConnectTrailList, ConnectTrailOutsideClick."),
            stageHeight: 520,
            behaviours: [
                .init(trigger: "Click a server in the rail", result: "With the tree showing, the tree glides to that server and the rail keeps it selected while it does. While you scroll, the rail marks the server whose card is at the top."),
                .init(trigger: "Click a server with the tree hidden", result: "The tree opens and, as it slides in, scrolls to that server; the rail's disc shows which one (round 40). The glass peek and its setting are gone."),
                .init(trigger: "Refresh in the toolbar", result: "Only while the front tab can reload (tool tabs; never a query tab). It shows only its own reload: a spinner, then ✓ or ✗. ⌘R (View › Reload Tab) does the same (round 34)."),
                .init(trigger: "Server connecting", result: "Its monogram breathes until it connects; with Reduce Motion it stays still and dimmed."),
                .init(trigger: "Connection lost", result: "The monogram dims to 40%; the name bubble says why."),
                .init(trigger: "Hover a server", result: "The monogram turns primary and a glass bubble opens at once to its right, over the tree, with the name, the product line and a line for connecting, lost, or how many queries are running (round 51, NM1; the system tooltip is gone). Running queries show nothing else in the rail."),
                .init(trigger: "Right-click a server, Customize Appearance", result: "A popover opens at the item: colour swatches and a picker, 12 symbols and 8 emoji, and Reset to Automatic. A chosen symbol or emoji replaces the two letters (an SF Symbol in the server's colour); each pick is saved at once and shows in the trail, the Manage Connections list and the connection sheet (round 51, TI0, CU2, WH2, WS0)."),
                .init(trigger: "Minimize a card with its header's chevron", result: "The card leaves the tree (it fades and settles to 97% from its top edge, the cards below rise to close the gap) and its server in the rail glides below a short hairline in the connected pill, looking exactly as before: no ring, no dimming, no mark (round 55, DV0; round 51's SH5 dashed ring is gone). The hairline is 1pt high, 60% of an item's width, primary text at 14%, and shows only when both open and minimized servers exist. Click the item: the card returns, the tree glides to it, it selects and glides back above the line. VoiceOver adds minimized. With every card minimized the tree says All Servers Are Minimized. There is no Expand one connection at a time setting any more; cards open and close independently."),
                .init(trigger: "Recent servers", result: "Saved connections of the project that are not connected, most recently used first (3, 5 or 8 of them, default 5), in a glass capsule of their own 8pt below the connected pill, dimmed to 38% (round 55, SE0). Click one: it breathes while it connects, then glides up into the connected pill; if it fails it joins the connected pill as a lost server. Hovering one opens the same glass name bubble as a connected server (name, product, and Not connected, click to connect). Right-click: Connect, Customize Appearance, Edit Connection, Remove from Recents (persisted; it returns when connected again). Disconnect (the item's menu) drops the server to the top of the recents. The pill is absent with no recents, and Settings › Appearance › Server Trail › Show Recent Servers turns it off."),
                .init(trigger: "Click the server rack button (or ⇧⌘K)", result: "A glass drawer slides in beside the trail, over the tree, the height of the rail (round 56, replacing round 52's widening pill). The pills stay as they are and stay usable: switching server, a recent connecting, minimizing. The rack in the circle turns to an × (the circle is now the close button). The drawer holds a search field (focused, prompt Search connections) with New Connection, Manage Connections, Quick Connect and × as four icon buttons beside it, then the saved connections not already open, under their folder's name (Saved for none), each a mark, a name and host · database. Return connects the highlighted row (the first match until an arrow key or the pointer picks another), Escape, ×, the circle or a click anywhere outside the rail and the drawer closes it; a click on a server selects it and keeps the drawer open. File › Connect To keeps the system menu for the menu bar."),
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
                .init(name: "Open the connect drawer", curve: "house spring", duration: "0.45s", note: "echoMotion.standard; the drawer moves in from its leading edge with opacity, the rack turns to an × (symbol replace)"),
                .init(name: "Close the connect drawer", curve: "smooth, no overshoot", duration: "0.45s", note: "echoMotion.settle; the same move and fade, back"),
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
                .init(label: "Own symbol or emoji", value: "an SF Symbol 40% of the item (13.6pt at 34pt), semibold; an emoji 46%", token: "LayoutTokens.Rail.glyphSymbolRatio / glyphEmojiRatio"),
                .init(label: "Name bubble", value: "glass, corners 12pt, 8pt right of the item; name 13pt semibold, product 11pt secondary", token: "LayoutTokens.Rail.nameBubbleGap / ServerRailNameBubble"),
                .init(label: "Rail pill padding", value: "4pt", token: "LayoutTokens.Rail.pillPadding"),
                .init(label: "Selection disc", value: "the item minus 3pt on every side, filled with the text background, shadow black 16% radius 1.5 y 0.5", token: "ColorTokens.Workspace.railSelection / ShadowTokens.railSelection / LayoutTokens.Rail.selectionInset"),
                .init(label: "Welcome", value: "420pt wide, mark 120pt wide (no name), recents on a card with 28pt rows", token: "LayoutTokens.Welcome"),
                .init(label: "Server page", value: "600pt wide, name 26pt bold", token: "LayoutTokens.ServerPage"),
                .init(label: "Connect drawer", value: "250pt wide (3.9 × 64), the height of the rail, 8pt from the rail column, corners 24pt", token: "ServerRail.connectDrawerWidth / connectDrawerGap / SpacingTokens.lg"),
                .init(label: "Trail icon buttons", value: "28pt, symbols 13pt medium, the × 11pt semibold; secondary, primary on hover", token: "ConnectTrailIconButton"),
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
                .init(text: "Connecting is its own glass circle, not a + in the pill",
                      why: "With one server the pill held a single item and read as a double border; round 55 moved connecting to a circle of its own under the pills, with a server rack glyph, and removed the + everywhere (FM0, CI1).",
                      rounds: ["decided.rail-servers", "ongoing.trail-item-states-r55"]),
                .init(text: "A minimized server is marked by its place, never by a mark",
                      why: "The dashed ring (round 51) looked ugly. Minimized servers sit below a short hairline, each item unchanged; recents are dimmed because they are disconnected (round 55).",
                      rounds: ["ongoing.trail-item-states-r55"]),
                .init(text: "The server rack button opens a drawer beside the trail, not a menu and not the pill widening",
                      why: "Round 52 widened the pill into the list; round 56 replaced it: the pills stay visible and usable beside a drawer the height of the rail, the circle turns to the close button, and a click outside, Escape or the × closes it.",
                      rounds: ["ongoing.connect-menu-r52", "ongoing.connect-card-r56"]),
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
                "Echo/Sources/Features/ObjectBrowser/Views/Components/ServerRail+ConnectTrail.swift",
                "Echo/Sources/Features/ObjectBrowser/Views/Components/ConnectTrail/ConnectTrailListing.swift",
                "Echo/Sources/Features/ObjectBrowser/Views/Components/ConnectTrail/ConnectTrailList.swift",
                "Echo/Sources/Features/AppHost/EchoApp+ConnectToMenu.swift",
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
