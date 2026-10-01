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
                .material(.row("Fill", "the workspace canvas", token: "ColorTokens.Workspace.canvas", swatch: ColorTokens.Workspace.canvas),
                          .row("Glass", "none")),
            ], rounds: [canvasRound], files: [workspace]),
            SpecElement(number: "1.2", name: "Card", summary: "The one card look: the tree, editor and results all use it.", groups: [
                .material(.row("Fill", "opaque; the shadow is drawn by the fill behind the content, so AppKit content is never rendered offscreen for it", token: "ColorTokens.Workspace.card", swatch: ColorTokens.Workspace.card),
                          .row("Glass", "never on a card: glass over a flat canvas has nothing to refract and reads as a grey box"),
                          .row("Edge", "0.5pt, 35% separator", token: "cardEdgeWidth / cardEdgeOpacity"),
                          .row("Shadow", "black 12%, blur 10, y 4", token: "ShadowTokens.workspaceCard")),
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
        SpecPart(number: "2", name: "Server rail", summary: "Two glass pills down the window's left edge: servers, and tools.", elements: [
            SpecElement(number: "2.1", name: "Rail", summary: "The server pill on top, the tool pill at the bottom, and the space between.", groups: [
                .layout(.row("Width", "item + 2 × pill padding: 42pt at the default", token: "LayoutTokens.Rail.width(itemSize:)"),
                        .row("Smallest gap between pills", "12pt", token: "LayoutTokens.Rail.minimumPillGap")),
                .behaviour(.row("Click a server", "the tree jumps to it; the rail marks the server whose rows are at the top while you scroll")),
            ], rounds: [railRound], files: [rail, tokens]),
            SpecElement(number: "2.2", name: "Server pill", summary: "A glass capsule holding the servers and the + that ends it.", groups: [
                .material(.row("Glass", "Liquid Glass, regular, capsule")),
                .layout(.row("Padding", "4pt", token: "LayoutTokens.Rail.pillPadding"), .row("Item spacing", "4pt", token: "LayoutTokens.Rail.itemSpacing"),
                        .row("Scrolls", "when the servers don't fit; bounces only when it must")),
                .motion(.row("A server joins or leaves", "grows and shrinks, house spring, 0.45s")),
            ], rounds: [railRound], files: [rail]),
            SpecElement(number: "2.3", name: "Server item", summary: "A two-letter monogram.", groups: [
                .layout(.row("Size", "28 · 34 (default) · 40pt, a setting", token: "RailItemSize.points")),
                .type(.row("Monogram", "37% of the size: 12.5pt at 34pt, rounded design", token: "LayoutTokens.Rail.monogramFontRatio"),
                      .row("Unselected", "semibold, secondary; primary while hovered"), .row("Selected", "bold, in the server's colour"),
                      .row("Server Header Color: Server's Color", "always in the server's colour, bold when selected (round 30.1, CO1); the colour is read live, so one set from the header's menu shows at once", token: "ServerRailItem.isAlwaysColored")),
                .behaviour(.row("Letters", "numbers-only words: the last two digits; two words: their initials; a name ending in two digits: those digits; otherwise its first two letters", token: "ServerRailMonogram.make"),
                           .row("Tooltip", "name · host, then Connecting…, Connection lost: reason, or N queries running", token: "ServerRailEntry.tooltip"),
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
            SpecElement(number: "2.7", name: "Connection lost", summary: "The monogram dims; the tooltip says why.", groups: [
                .states(.row("Opacity", "40%", token: "LayoutTokens.Rail.lostOpacity")),
            ], files: [rail]),
            SpecElement(number: "2.8", name: "New connection button", summary: "A + at the end of the server pill.", groups: [
                .type(.row("Glyph", "plus, 13pt medium, secondary")),
                .behaviour(.row("Click", "opens the connections menu: open sessions, saved connections by folder, Manage Connections, Quick Connect", token: "ConnectionsMenuContent"),
                           .row("Never selected", "the disc never moves onto it"), .row("Tooltip", "Connect to a Server")),
            ], rounds: [railRound], files: [rail]),
            SpecElement(number: "2.9", name: "Tool pill", summary: "A glass capsule of four tool buttons at the bottom of the rail.", groups: [
                .layout(.row("Tools", "Bookmarks, Snippets, History, Clipboard", token: "SidebarMenu.NavSection.railTools"),
                        .row("Button", "the server pill's width, 30pt high", token: "LayoutTokens.Rail.toolHeight"), .row("Spacing", "2pt", token: "LayoutTokens.Rail.toolSpacing"),
                        .row("Padding", "4pt on every side, like the server pill", token: "LayoutTokens.Rail.pillPadding")),
                .type(.row("Symbols", "13pt; secondary, primary on hover", token: "LayoutTokens.Rail.toolSymbolSize")),
                .states(.row("Showing", "the filled symbol in the accent colour")),
                .behaviour(.row("Click", "its page shows in the tree's place and the tree opens if hidden"), .row("Click the one showing", "back to the tree"),
                           .row("Tooltip", "the tool's name")),
            ], rounds: [railRound], files: [rail]),
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
            SpecElement(number: "3.3", name: "Peek", summary: "Click a server with the tree hidden.", groups: [
                .material(.row("Card", "glass, 18pt corners, over the cards", token: "LayoutTokens.FloatingSurface.cornerRadius")),
                .behaviour(.row("Plain click", "the tree slides out over the cards, which don't move"),
                           .row("Puts it away", "a click on the cards, Esc, opening a tab, showing the tree, or a plain click on the server that is peeking"),
                           .row("⌘-click or double-click", "shows the tree for good"),
                           .row("Setting", "Collapsed Server Click: peek and ⌘-click (default), always peek, always show the tree", token: "CollapsedServerClickBehavior")),
                .motion(.row("Peek", "house spring, 0.45s")),
            ], files: [workspace]),
            SpecElement(number: "3.4", name: "Layout", summary: "How the rail, tree, cards and inspector share the window.", groups: [
                .layout(.row("Order", "rail · tree · cards · inspector column, on the canvas"),
                        .row("Top", "the rail and tree start half the tab strip's spare height below the toolbar, so the rail, tree and tab plate line up"),
                        .row("Gutters", "the gutter setting on the outer edges; the tree's trailing gutter is its resize handle")),
                .behaviour(.row("Tree width", "remembered", token: "workspace.treeWidth")),
            ], files: [workspace]),
        ]),
        SpecPart(number: "4", name: "Empty states", summary: "What the content area shows without a tab.", elements: [
            SpecElement(number: "4.1", name: "Welcome", summary: "No server and no tab. Sits on the canvas, with no card.", groups: [
                .layout(.row("Width", "420pt", token: "LayoutTokens.Welcome.width"), .row("Icon", "32pt", token: "LayoutTokens.Welcome.iconSize"),
                        .row("Title", "Echo, 26pt bold", token: "LayoutTokens.Welcome.titleSize")),
                .behaviour(.row("Buttons", "Connect… (glass, prominent, opens the connections menu), Quick Connect and Manage (glass), large"),
                           .row("Recent", "the latest five connections on one small card: monogram in its colour, name, host, how long ago; a click connects", token: "WorkspaceWelcomeView.maximumRecentCount"),
                           .row("Why no card", "cards are only for content")),
            ], rounds: [canvasRound], files: [welcome]),
            SpecElement(number: "4.2", name: "Server page", summary: "A server is active but no tab is open. Sits on the canvas, with no card.", groups: [
                .layout(.row("Width", "600pt", token: "LayoutTokens.ServerPage.width"), .row("Name", "26pt bold", token: "LayoutTokens.ServerPage.nameSize"),
                        .row("Top", "lines up with the rail's top")),
                .type(.row("Version", "13pt secondary, one line")),
                .behaviour(.row("Content", "the name (a Beta badge for beta engines), the version, the server's tools on glass buttons with New Query first, and a databases card with a filter"),
                           .row("Tooltip", "the host")),
            ], rounds: [canvasRound], files: [serverPage]),
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
