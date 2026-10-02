import SwiftUI

/// The window by piece, each with a stable ID (`WIN-2.4`). Values come from `LayoutTokens.Workspace`
/// and `LayoutTokens.Rail`, `WorkspaceView` and the rail.
@MainActor
enum WindowSpec {
    private static let workspace = "Echo/Sources/Features/AppHost/Views/Navigation/WorkspaceShell.swift"
    private static let welcome = "Echo/Sources/Features/AppHost/Views/Tabs/WorkspaceContainer/WorkspaceWelcomeView.swift"
    private static let serverPage = "Echo/Sources/Features/AppHost/Views/Tabs/EditorContainer/ConnectionDashboard/ConnectionDashboardView.swift"
    private static let rail = "Echo/Sources/Features/ObjectBrowser/Views/Components/ServerRail.swift"
    private static let tokens = "Packages/EchoDesignSystem/Sources/EchoDesignSystem/Tokens/LayoutToken.swift"
    private static let canvasRound = "decided.window-canvas-and-cards"
    private static let railRound = "decided.rail-servers"

    static func spec() -> AreaSpec {
        AreaSpec(code: "WIN", stageHeight: 520, parts: parts) { WindowSpecimen() }
    }

    private static let parts: [SpecPart] = [
        SpecPart(number: "1", name: "Canvas and cards", summary: "A canvas holds the rail, the tree and the content cards.", elements: [
            SpecElement(number: "1.1", name: "Canvas", summary: "The window's background, behind everything.", groups: [
                .material(.row("Fill", "the window background in light; white 9.5% in dark, just under the cards (round 32.2, DC6)", token: "ColorTokens.Workspace.canvas", swatch: ColorTokens.Workspace.canvas),
                          .row("Glass", "none")),
            ], rounds: [canvasRound], files: [workspace]),
            SpecElement(number: "1.2", name: "Card", summary: "The one card look: the tree, editor and results all use it.", groups: [
                .material(.row("Fill", "opaque; the shadow is drawn by the fill behind the content, so AppKit content is never rendered offscreen for it", token: "ColorTokens.Workspace.card", swatch: ColorTokens.Workspace.card),
                          .row("Glass", "never on a card: glass over a flat canvas has nothing to refract and reads as a grey box"),
                          .row("Edge", "0.5pt at 35%: the separator in light, white 20% in dark (a 7% hairline; round 32.2, DE5)", token: "cardEdgeWidth / cardEdgeOpacity"),
                          .row("Lit top edge", "dark only: 1pt, primary 10% fading out by the card's middle (DE5)"),
                          .row("Increase Contrast", "a solid 1pt separator edge instead, no lit edge (IC0)"),
                          .row("Shadow", "light: black 12%, blur 10, y 4; dark: contact black 60%, blur 3, y 1 over ambient black 40%, blur 24, y 10 (DS5)", token: "ShadowTokens.workspaceCard / workspaceCardContact / workspaceCardAmbient")),
                .layout(.row("Corner", "continuous, from the Card Corners setting: 10, 12, 16 (default), 20 or 26pt", token: "workspaceCardCornerRadius / LayoutTokens.Workspace.cardCornerRadius"),
                        .row("Why 16", "the macOS 27 window corner, measured from a screenshot")),
                .behaviour(.row("Chrome", "a card whose content lays out cards of its own has no fill, shadow or edge, so theirs aren't cut off"),
                           .row("Fades", "fill, shadow and edge can fade together while a card dissolves into another")),
            ], rounds: [canvasRound], files: ["Echo/Sources/Shared/DesignSystem/Components/WorkspaceCard.swift", tokens]),
            SpecElement(number: "1.3", name: "Editor card", summary: "The top content card.", groups: [
                .behaviour(.row("Height", "full height until results show; then the results card lands on its bottom edge"),
                           .row("Kept alive", "the content sits in the same place whether the panel shows or not, so it keeps its scroll position, undo history and focus"),
                           .row("Split", "the editor takes between 25% and 80% of the height while you drag", token: "ContentPanelCards.minContentFraction / maxContentFraction")),
            ], rounds: ["decided.round10-footer-and-switcher"], files: [workspace]),
            SpecElement(number: "1.4", name: "Results card", summary: "The bottom content card, below the editor.", groups: [
                .behaviour(.row("Opens", "grows up out of the footer: it detaches as a footer-high card, the seam travels up to the split line and the panel fades in; closing runs it backwards (see Footer and results)"),
                           .row("While it grows", "the cards are laid out at fixed sizes and only their clips move")),
            ], files: [workspace]),
            SpecElement(number: "1.5", name: "Gap between panes", summary: "The space between the rail, the tree and the cards.", groups: [
                .layout(.row("Width", "4, 6 or 8pt (setting)", token: "Spacing Between Panes")),
            ], files: [workspace]),
            SpecElement(number: "1.6", name: "Gap handle", summary: "Drag the gap between the editor and results to resize them.", groups: [
                .layout(.row("Grab capsule", "36 × 4pt in tertiary, shown on hover", token: "gapHandleWidth / gapHandleHeight"),
                        .row("Extra hit area", "4pt above and below", token: "gapHitSlop"),
                        .row("Maximised results", "the editor keeps about one line: 40pt", token: "collapsedEditorHeight")),
                .behaviour(.row("Pointer", "row resize"), .row("Drag", "the editor card ends where the pointer is"),
                           .row("Double-click the gap", "maximises the results, or restores them"),
                           .row("Menu", "View › Maximize Results, Restore Editor, Maximize Bottom Panel: ⌥⇧⌘Y"),
                           .row("Accessibility", "Resize content and panel; the action Maximize or Restore Panel")),
                .motion(.row("Capsule", "fades in on hover, 0.12s", token: "echoMotion.hover")),
            ], files: [workspace, tokens]),
        ]),
        SpecPart(number: "2", name: "Server rail", summary: "One server glass pill down the window's left edge; saved SQL uses the inspector column (round 39).", elements: [
            SpecElement(number: "2.1", name: "Rail", summary: "The server pill on top, the tool pill at the bottom, and the space between.", groups: [
                .layout(.row("Width", "item + 2 × pill padding: 42pt at the default", token: "LayoutTokens.Rail.width(itemSize:)"),
                        .row("Smallest gap between pills", "12pt", token: "LayoutTokens.Rail.minimumPillGap")),
                .behaviour(.row("Click a server", "the tree jumps to it; the rail marks the server whose rows are at the top while you scroll")),
            ], rounds: [railRound], files: [rail, tokens]),
            SpecElement(number: "2.2", name: "Server pill", summary: "A glass capsule holding the connected servers: open ones above minimized ones, split by a short hairline (round 55).", groups: [
                .material(.row("Glass", "Liquid Glass, regular, capsule")),
                .layout(.row("Padding", "4pt", token: "LayoutTokens.Rail.pillPadding"), .row("Item spacing", "4pt", token: "LayoutTokens.Rail.itemSpacing"),
                        .row("Scrolls", "when the servers don't fit; bounces only when it must"),
                        .row("Hairline (round 55, DV0)", "between open servers (card in the tree) and minimized ones: 1pt high, 60% of an item's width, centred, primary text at 14%, 4pt above and below; shown only when both groups have a server; order inside a group is the connection order", token: "LayoutTokens.Rail.hairlineHeight, hairlineWidthRatio, hairlineOpacity / ServerRailLayout")),
                .motion(.row("A server joins or leaves", "grows and shrinks, house spring, 0.45s")),
            ], rounds: [railRound, "ongoing.trail-item-states-r55"], files: [rail]),
            SpecElement(number: "2.3", name: "Server item", summary: "A two-letter monogram, or the symbol or emoji the user chose for the server.", groups: [
                .layout(.row("Size", "28 · 34 (default) · 40pt, a setting", token: "RailItemSize.points")),
                .type(.row("Monogram", "37% of the size: 12.5pt at 34pt, rounded design", token: "LayoutTokens.Rail.monogramFontRatio"),
                      .row("Unselected", "semibold, secondary; primary while hovered"), .row("Selected", "bold, in the server's colour"),
                      .row("Server Header Color: Server's Color", "always in the server's colour, bold when selected (round 30.1, CO1); the colour is read live, so one set from the header's menu shows at once", token: "ServerRailItem.isAlwaysColored")),
                .behaviour(.row("Letters", "numbers-only words: the last two digits; two words: their initials; a name ending in two digits: those digits; otherwise its first two letters", token: "ServerRailMonogram.make"),
                           .row("Name bubble (round 51, NM1)", "hover shows a glass bubble to the right of the item at once, over the tree and taking no clicks: the name semibold, the product line secondary, and a third line for Connecting, Connection lost: reason, or N queries running. It replaces the system tooltip; VoiceOver reads the item's label and value. Closed trail only", token: "ServerRailNameBubble / ServerRail+Appearance"),
                           .row("Own symbol or emoji (round 51, TI0, CU2)", "set on the connection (railSymbol or railEmoji); it replaces the letters in the same place and size: an emoji as text at 46% of the item, an SF Symbol at 40%, semibold, always in the server's colour", token: "ServerRailMark / LayoutTokens.Rail.glyphSymbolRatio, glyphEmojiRatio"),
                           .row("Customize Appearance (round 51, WH2)", "the item's right-click menu opens a popover at the item with the colour swatches (the connection sheet's palette and colour picker), a grid of 12 symbols and 8 emoji, and Reset to Automatic; each pick is saved at once. The connection sheet shows the same view", token: "ServerAppearanceControls / ServerAppearancePopover"),
                           .row("Where the look shows (WS0)", "the trail, the Manage Connections list's Name column and the connection sheet's preview; not the tabs or the card header"),
                           .row("Minimized card (round 51, SH5, round 55)", "a server whose card is minimized (closed with its header chevron, so it is not in the tree) looks exactly like any connected server and sits below the hairline; nothing marks it (the dashed ring is gone); VoiceOver adds minimized. Clicking it restores the card, selects it and moves it back above the line (TREE-2.5)", token: "ServerRailLayout / ServerRailBridge.minimizedConnectionIDs"),
                           .row("Why a monogram", "colour dots and engine badges were rejected")),
            ], rounds: [railRound], files: [rail]),
            SpecElement(number: "2.4", name: "Selection disc", summary: "An opaque capsule behind the selected monogram.", groups: [
                .material(.row("Fill", "the text background: white in light, dark grey in dark", token: "ColorTokens.Workspace.railSelection", swatch: ColorTokens.Workspace.railSelection),
                          .row("Shadow", "black 16%, radius 1.5, y 0.5", token: "ShadowTokens.railSelection")),
                .layout(.row("Inset", "3pt inside its item on every side, so a single server never looks like a pill inside a pill", token: "LayoutTokens.Rail.selectionInset")),
                .behaviour(.row("Follows", "a server just clicked, else the one at the top of the tree, else the selected connection, else the first")),
            ], rounds: [railRound], files: [rail]),
            SpecElement(number: "2.5", name: "Selection motion", summary: "The liquid stretch: the disc's leading edge races, the trailing edge follows.", groups: [
                .motion(.row("Leading edge", "0.28s", token: "echoMotion.liquidLead"), .row("Trailing edge", "0.55s", token: "echoMotion.liquidTrail")),
            ], rounds: [railRound], files: [rail]),
            SpecElement(number: "2.6", name: "Connecting", summary: "The monogram breathes until the server connects.", groups: [
                .motion(.row("Opacity and size", "ease in-out, 0.7s half cycle, down to 15% and a slightly smaller monogram", token: "echoMotion.pulseHalfPeriod / EchoMotion.pulseMinimumOpacity")),
                .states(.row("Reduce Motion", "still, at 40%", token: "LayoutTokens.Rail.lostOpacity")),
            ], files: [rail]),
            SpecElement(number: "2.7", name: "Connection lost", summary: "The monogram dims; the name bubble says why.", groups: [
                .states(.row("Opacity", "40%", token: "LayoutTokens.Rail.lostOpacity")),
            ], files: [rail]),
            SpecElement(number: "2.8", name: "Connect to a Server button", summary: "A glass circle under the recents pill, or under the connected pill when there are no recents (round 55: FM0, CI1). It replaced the +.", groups: [
                .material(.row("Glass", "Liquid Glass, regular, circle; padded as the pills", token: "LayoutTokens.Rail.pillPadding")),
                .type(.row("Glyph", "server.rack, 13pt, secondary", token: "LayoutTokens.Rail.connectSymbol, toolSymbolSize")),
                .behaviour(.row("Click", "opens the trail into the saved connections (2.10); ⇧⌘K does the same", token: "AppState.isConnectTrailOpen"),
                           .row("File › Connect To", "the system menu with open sessions, saved connections by folder, Manage Connections and Quick Connect, for the menu bar", token: "ConnectionsMenuContent"),
                           .row("Never selected", "the disc never moves onto it"), .row("Tooltip", "Connect to a Server")),
            ], rounds: [railRound], files: [rail]),
            SpecElement(number: "2.9", name: "Tool pill (retired)", summary: "Removed in round 39; Bookmarks and History moved to the inspector column.", groups: [
                .behaviour(.row("Removed", "Snippets and Echo clipboard history are gone; rail is servers and the connect button only")),
            ], rounds: ["ongoing.rail-tools-r39", "ongoing.rail-clipboard-r39"], files: [rail], isRetired: true),
            SpecElement(number: "2.10", name: "Opened trail", summary: "The server pill widened into the list of saved connections (round 52: PR4, MP2, CT1, OP1, CX1, KB1, SM1).", groups: [
                .material(.row("Glass", "the same single glass shape as the closed pill; corners 24pt open, a capsule closed", token: "SpacingTokens.lg")),
                .layout(.row("Width", "250pt (3.9 × 64): the pill overflows the rail column to the right, over the tree", token: "ServerRail.connectTrailWidth"),
                        .row("List", "320pt high, scrolls; a soft edge top and bottom", token: "ServerRail.connectTrailListHeight"),
                        .row("Header", "the connected servers in a row on the left, the rail's own items with the white selection disc, scrolling sideways under a soft edge; at the right New Connection, Manage Connections, Quick Connect and ×, 28pt icon buttons"),
                        .row("Rows", "a 24pt mark with two letters, the name (13pt), host · database under it (11pt, tertiary); folders as small semibold headings, Saved for connections in none"),
                        .row("List holds", "saved connections not already open; no Open section, no footer")),
                .behaviour(.row("Open", "the server rack button or ⇧⌘K; the search field has the focus"),
                           .row("Search", "name or host · database, ignoring case and accents; the first match is highlighted", token: "ConnectTrailListing"),
                           .row("Return", "connects the highlighted row and closes"), .row("↑ ↓", "move the highlight"),
                           .row("Escape or ×", "closes"), .row("A server in the header", "selects it and closes"),
                           .row("New Connection", "opens Manage Connections on an empty form", token: "ManageConnectionsWindowController.present(startingNewConnection:)")),
                .motion(.row("Open", "house spring: the recents pill and the circle fade out, the servers glide from the column into the row, the rack to the ×, the list fades in", token: "echoMotion.standard"),
                        .row("Close", "the list fades out first (0.12s), then the glass settles with no overshoot", token: "echoMotion.settle")),
            ], rounds: ["ongoing.connect-menu-r52"], files: [rail]),
            SpecElement(number: "2.11", name: "Recents pill", summary: "Recent servers in a glass capsule of their own, 8pt below the connected pill (round 55: SE0, DC0).", groups: [
                .material(.row("Glass", "Liquid Glass, regular, capsule, the pills' padding and item spacing")),
                .layout(.row("Holds", "saved connections of the project that are not connected and not connecting, most recently used first, at most 3, 5 (default) or 8", token: "ServerRailLayout / GlobalSettings.recentServerCount"),
                        .row("Source", "the persisted connection history: a connection is moved to its top when it connects and when it is disconnected", token: "EnvironmentState.recentConnections / HistoryRepository"),
                        .row("Absent", "when there are no recents, or Show Recent Servers is off")),
                .states(.row("Item", "the server's own mark, dimmed: its colour at 38%, the letters as the rail draws them", token: "LayoutTokens.Rail.recentOpacity"),
                        .row("Connecting", "the item breathes (the connecting breathing) while it connects; it stays here until connected")),
                .behaviour(.row("Click", "connects the server; once connected it glides up into the connected pill, open group, card in the tree"),
                           .row("Failure", "the server joins the connected pill as a lost server"),
                           .row("Disconnect", "the server drops to the top of the recents, dimmed"),
                           .row("Setting", "Settings › Appearance › Server Trail: Show Recent Servers and Number of Recent Servers (3, 5, 8; disabled while off)", token: "GlobalSettings.showsRecentServers, recentServerCount")),
                .motion(.row("Move", "items glide between the groups and the pills with one matched-geometry namespace on the house spring", token: "echoMotion.standard")),
            ], rounds: ["ongoing.trail-item-states-r55"], files: [rail, "Echo/Sources/Features/ObjectBrowser/Views/Components/ServerRail+Recents.swift", "Echo/Sources/Features/ObjectBrowser/Views/Components/ServerRailLayout.swift"]),
        ]),
        SpecPart(number: "3", name: "Tree column", summary: "The Explorer's cards, between the rail and the content.", elements: [
            SpecElement(number: "3.1", name: "Column", summary: "One card per server; see the Explorer tree area.", groups: [
                .layout(.row("Width", "260pt ideal, 200 to 480", token: "treeIdealWidth / treeMinWidth / treeMaxWidth"),
                        .row("Resize handle", "8pt, invisible, on the trailing edge", token: "treeResizeHandleWidth")),
                .motion(.row("Drag", "one smooth width change, no stepped jumps")),
            ], files: [workspace, tokens]),
            SpecElement(number: "3.2", name: "Hide and show", summary: "⌃⌘S or the sidebar button toggles the tree.", groups: [
                .motion(.row("Hide", "smooth, no overshoot, 0.45s: the tree slides left behind the rail as it fades and its space collapses so the cards grow", token: "echoMotion.settle"),
                        .row("Show", "house spring, 0.45s", token: "echoMotion.standard"), .row("Reduce Motion", "fades only")),
                .behaviour(.row("While hidden", "the tree stays alive: it keeps its rows, scroll position and open folders"),
                           .row("Nothing to show", "the tree stays hidden and ⌃⌘S does nothing until a server connects or you pick a tool", token: "WorkspaceTreeAvailability.hasContent"),
                           .row("Button", "Hide Sidebar or Show Sidebar (⌃⌘S); disabled, with a reason, while there is nothing to show")),
            ], files: [workspace]),
            SpecElement(number: "3.3", name: "Peek", summary: "The tree sliding out on glass over the cards when a server was clicked with it hidden. Removed in round 40, with its setting; a click opens the tree (WIN-3.5).", isRetired: true),
            SpecElement(number: "3.4", name: "Layout", summary: "How the rail, tree, cards and inspector share the window.", groups: [
                .layout(.row("Order", "rail · tree · cards · inspector column, on the canvas"),
                        .row("Top", "the rail and tree start half the tab strip's spare height below the toolbar, so the rail, tree and tab plate line up"),
                        .row("Gutters", "the gutter setting on the outer edges; the tree's trailing gutter is its resize handle")),
                .behaviour(.row("Tree width", "remembered", token: "workspace.treeWidth")),
            ], files: [workspace]),
            SpecElement(number: "3.5", name: "Server click with the tree hidden", summary: "Opens the tree, scrolled to that server (round 40, RC1).", groups: [
                .behaviour(.row("Click", "shows the tree and selects the server; any click, no modifiers or settings", token: "WorkspaceRailColumn.selectSession"),
                           .row("Arrival", "nothing more: the rail's disc shows which server it is (SM1)"),
                           .row("Tree showing", "the tree scrolls to the server's card, as before (TV0)")),
                .motion(.row("Together", "the tree slides in on the house spring (0.45s) while it scrolls to the server (smooth, 0.40s), one movement (OM0)", token: "echoMotion.standard / echoMotion.reveal")),
            ], rounds: ["ongoing.rail-click-hidden-tree-r40"], files: [workspace]),
        ]),
        SpecPart(number: "4", name: "Empty states", summary: "What the content area shows without a tab.", elements: [
            SpecElement(number: "4.1", name: "Welcome", summary: "No server and no tab. Sits on the canvas, with no card.", groups: [
                .layout(.row("Width", "420pt", token: "LayoutTokens.Welcome.width"), .row("Mark", "120pt wide, the three pills alone: no tile, no name", token: "LayoutTokens.Welcome.markWidth")),
                .behaviour(.row("Buttons", "Connect… (glass, prominent, opens the connections menu), Quick Connect and Manage (glass), large"),
                           .row("Recent", "the latest five connections on one small card: monogram in its colour, name, host, how long ago; a click connects", token: "WorkspaceWelcomeView.maximumRecentCount"),
                           .row("Why no card", "cards are only for content")),
                .motion(.row("Arrives", "each time the welcome appears: the pills echo in (0.9s, 0.12s apart, overshoot), then the buttons and the recents rise 10pt, 0.15s apart", token: "WelcomeMarkMotion"),
                        .row("Leaves", "when a server connects the pills echo out to the left (0.46s) and the rest fades; the rail, the tree and the page wait", token: "AppState.welcomeDeparture")),
            ], rounds: [canvasRound, "ongoing.opening-and-closing-r48"], files: [welcome]),
            SpecElement(number: "4.2", name: "Server page", summary: "A server is active but no tab is open. Sits on the canvas, with no card.", groups: [
                .layout(.row("Width", "600pt", token: "LayoutTokens.ServerPage.width"), .row("Name", "26pt bold", token: "LayoutTokens.ServerPage.nameSize"),
                        .row("Top", "lines up with the rail's top")),
                .type(.row("Version", "13pt secondary, one line")),
                .behaviour(.row("Content", "the name (a Beta badge for beta engines), the version, the server's tools on glass buttons with New Query first, and a databases card with a filter"),
                           .row("Tooltip", "the host")),
                .motion(.row("Arrives", "builds up: name, version, tools, databases rise 8pt and fade in, 0.06s apart", token: "WelcomeMarkMotion.pieceGap"),
                        .row("Closing the last tab", "the server stays active; the page sits under the tabs and the card lifts away in 0.28s", token: "WelcomeMarkMotion.revealDuration")),
            ], rounds: [canvasRound, "ongoing.opening-and-closing-r48"], files: [serverPage]),
        ]),
        SpecPart(number: "5", name: "Refresh", summary: "The toolbar's Refresh and ⌘R (round 34).", elements: [
            SpecElement(number: "5.1", name: "Refresh button", summary: "In the right-hand capsule, before the bell, only while the front tab can reload.", groups: [
                .behaviour(.row("Shown", "Activity Monitor, Agent Jobs, Error Log, Extended Events, Structure, maintenance, diagrams, Profiler, Resource Governor, Tuning Advisor, Policy Management", token: "TabReloader.canReload"),
                           .row("Hidden", "query tabs and no tab: the schema reloads from the tree's menu and after DDL"),
                           .row("Shows", "only its own reload: a spinner, ✓ for 1.2 s or ✗ for 2 s; hover after 3 s to cancel"),
                           .row("⌘R", "View › Reload Tab, the same reload")),
            ], files: ["Echo/Sources/Features/AppHost/Views/Toolbar/RefreshToolbarButton/RefreshToolbarButton.swift",
                       "Echo/Sources/Features/AppHost/Views/Toolbar/RefreshToolbarButton/TabReloader.swift"]),
        ]),
    ]
}
