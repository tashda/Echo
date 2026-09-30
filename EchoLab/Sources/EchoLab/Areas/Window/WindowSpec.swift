import SwiftUI

/// The window by piece, each with a stable ID (`WIN-2.4`). Values come from `LayoutTokens.Workspace`
/// and `LayoutTokens.Rail`, `WorkspaceView` and the rail.
@MainActor
enum WindowSpec {
    private static let workspace = "Echo/Sources/Features/AppHost/Views/Navigation/WorkspaceView.swift"
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
                .material(.row("Fill", "opaque", token: "ColorTokens.Workspace.card", swatch: ColorTokens.Workspace.card),
                          .row("Glass", "never on a card: glass over a flat canvas has nothing to refract and reads as a grey box"),
                          .row("Edge", "0.5pt, 35% separator", token: "cardEdgeWidth / cardEdgeOpacity"),
                          .row("Shadow", "black 12%, blur 10, y 4", token: "ShadowTokens.workspaceCard")),
                .layout(.row("Corner", "16pt continuous (Card Corners setting: 10 to 26)", token: "LayoutTokens.Workspace.cardCornerRadius"),
                        .row("Why 16", "the macOS 27 window corner, measured from a screenshot")),
            ], rounds: [canvasRound], files: ["Echo/Sources/Shared/DesignSystem/Components/WorkspaceCard.swift", tokens]),
            SpecElement(number: "1.3", name: "Editor card", summary: "The top content card.", groups: [
                .behaviour(.row("Height", "full height until results show; then the results card lands on its bottom edge")),
            ], rounds: ["decided.round10-footer-and-switcher"], files: [workspace]),
            SpecElement(number: "1.4", name: "Results card", summary: "The bottom content card, below the editor.", groups: [
                .behaviour(.row("Opens", "grows up out of the footer (see Footer and results)")),
            ], files: [workspace]),
            SpecElement(number: "1.5", name: "Gap between panes", summary: "The space between the rail, the tree and the cards.", groups: [
                .layout(.row("Width", "4, 6 or 8pt (setting)", token: "Spacing Between Panes")),
            ], files: [workspace]),
            SpecElement(number: "1.6", name: "Gap handle", summary: "Drag the gap between the editor and results to resize them.", groups: [
                .layout(.row("Grab capsule", "36 × 4pt, shown on hover", token: "gapHandleWidth / gapHandleHeight"),
                        .row("Extra hit area", "4pt above and below", token: "gapHitSlop"),
                        .row("Maximised results", "the editor keeps about one line: 40pt", token: "collapsedEditorHeight")),
                .behaviour(.row("Double-click the gap", "maximises the results")),
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
                .layout(.row("Size", "34pt (small and large are a setting)", token: "RailItemSize.points")),
                .type(.row("Monogram", "37% of the size: 12.5pt at 34pt, rounded design", token: "LayoutTokens.Rail.monogramFontRatio"),
                      .row("Unselected", "semibold, secondary"), .row("Selected", "bold, in the server's colour")),
                .behaviour(.row("Tooltip", "the name and host"), .row("Why a monogram", "colour dots and engine badges were rejected")),
            ], rounds: [railRound], files: [rail]),
            SpecElement(number: "2.4", name: "Selection disc", summary: "An opaque capsule behind the selected monogram.", groups: [
                .material(.row("Fill", "opaque, the card colour"), .row("Shadow", "black 16%, radius 1.5, y 0.5")),
                .layout(.row("Inset", "3pt inside its item, so a single server never looks like a pill inside a pill", token: "LayoutTokens.Rail.selectionInset")),
            ], rounds: [railRound], files: [rail]),
            SpecElement(number: "2.5", name: "Selection motion", summary: "The liquid stretch: the disc's leading edge races, the trailing edge follows.", groups: [
                .motion(.row("Leading edge", "0.28s", token: "echoMotion.liquidLead"), .row("Trailing edge", "0.55s", token: "echoMotion.liquidTrail")),
            ], rounds: [railRound], files: [rail]),
            SpecElement(number: "2.6", name: "Connecting", summary: "The monogram breathes until the server connects.", groups: [
                .motion(.row("Opacity", "breathes, 0.7s half cycle, down to 15%", token: "echoMotion.pulseHalfPeriod")),
                .states(.row("Reduce Motion", "a steady 40%", token: "LayoutTokens.Rail.lostOpacity")),
            ], files: [rail]),
            SpecElement(number: "2.7", name: "Connection lost", summary: "The monogram dims; the tooltip says why.", groups: [
                .states(.row("Opacity", "40%", token: "LayoutTokens.Rail.lostOpacity")),
            ], files: [rail]),
            SpecElement(number: "2.8", name: "New connection button", summary: "A + at the end of the server pill.", groups: [
                .type(.row("Glyph", "plus, 13pt medium, secondary")),
                .behaviour(.row("Click", "opens the connections menu (New Connection, Quick Connect, Manage)"),
                           .row("Never selected", "the disc never moves onto it"), .row("Tooltip", "Connections")),
            ], rounds: [railRound], files: [rail]),
            SpecElement(number: "2.9", name: "Tool pill", summary: "A glass capsule of tool buttons at the bottom of the rail.", groups: [
                .layout(.row("Button height", "30pt", token: "LayoutTokens.Rail.toolHeight"), .row("Spacing", "2pt", token: "LayoutTokens.Rail.toolSpacing")),
                .type(.row("Symbols", "13pt", token: "LayoutTokens.Rail.toolSymbolSize")),
            ], rounds: [railRound], files: [rail]),
        ]),
        SpecPart(number: "3", name: "Tree column", summary: "The Explorer's cards, between the rail and the content.", elements: [
            SpecElement(number: "3.1", name: "Column", summary: "One card per server; see the Explorer tree area.", groups: [
                .layout(.row("Width", "260pt ideal, 200 to 480", token: "treeIdealWidth / treeMinWidth / treeMaxWidth"),
                        .row("Resize handle", "8pt, invisible, on the trailing edge", token: "treeResizeHandleWidth")),
                .motion(.row("Drag", "one smooth width change, no stepped jumps")),
            ], files: [workspace, tokens]),
            SpecElement(number: "3.2", name: "Hide and show", summary: "⌃⌘S toggles the tree.", groups: [
                .motion(.row("Hide", "smooth, no overshoot, 0.45s; the tree slides left behind the rail", token: "echoMotion.settle"),
                        .row("Show", "house spring, 0.45s")),
                .behaviour(.row("Nothing to show", "the tree hides and ⌃⌘S does nothing")),
            ], files: [workspace]),
            SpecElement(number: "3.3", name: "Peek", summary: "Click a server with the tree hidden.", groups: [
                .behaviour(.row("Plain click", "the tree slides out over the cards"), .row("Click away or Esc", "slides it back"),
                           .row("⌘-click or double-click", "reopens the tree for good (a setting changes this)")),
            ], files: [workspace]),
        ]),
        SpecPart(number: "4", name: "Empty states", summary: "What the content area shows without a tab.", elements: [
            SpecElement(number: "4.1", name: "Welcome", summary: "No server and no tab. Sits on the canvas, with no card.", groups: [
                .behaviour(.row("Content", "icon, Connect, Quick Connect, Manage, then the 5 latest connections"), .row("Why no card", "cards are only for content")),
            ], rounds: [canvasRound], files: [workspace]),
            SpecElement(number: "4.2", name: "Server page", summary: "A server is active but no tab is open. Sits on the canvas, with no card.", groups: [
                .behaviour(.row("Content", "the name, its version, glass tool buttons with New Query first, and a databases card")),
            ], rounds: [canvasRound], files: [workspace]),
        ]),
    ]
}
