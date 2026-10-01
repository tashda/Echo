import SwiftUI

/// The inspector by piece, each with a stable ID (`INS-2.1`).
@MainActor
enum InspectorSpec {
    private static let workspace = "Echo/Sources/Features/AppHost/Views/Navigation/WorkspaceView.swift"
    private static let section = "Echo/Sources/Shared/DesignSystem/Components/InspectorSection.swift"
    private static let column = "decided.inspector-column"
    private static let r15 = "ported.Round 15 · inspector"

    static func spec<Specimen: View>(stageHeight: CGFloat, @ViewBuilder specimen: @escaping () -> Specimen) -> AreaSpec {
        AreaSpec(code: "INS", stageHeight: stageHeight, parts: parts, specimen: specimen)
    }

    private static let parts: [SpecPart] = [
        SpecPart(number: "1", name: "Column", summary: "A column on the canvas, mirroring the tree: tree, cards, inspector.", elements: [
            SpecElement(number: "1.1", name: "Card", summary: "One workspace card holds every section.", groups: [
                .material(.row("Fill", "opaque, the workspace card", token: "ColorTokens.Workspace.card", swatch: ColorTokens.Workspace.card),
                          .row("Edge and shadow", "as every card", token: "cardEdge / ShadowTokens.workspaceCard")),
                .layout(.row("Padding", "12pt, single (not doubled)", token: "LayoutTokens.Inspector.cardPadding"),
                        .row("Why one card", "stacked shadows were cut off at the column's edges"),
                        .row("Window edge", "a gutter after the card, as the tree has on the rail's side")),
                .behaviour(.row("Scrolls", "without indicators")),
            ], rounds: [column, r15], files: [workspace]),
            SpecElement(number: "1.2", name: "Show and hide", summary: "The inspector button toggles the column.", groups: [
                .motion(.row("Show", "house spring, 0.45s", token: "echoMotion.standard"), .row("Hide", "settles without overshoot, 0.45s: it slides out past the trailing edge and fades", token: "echoMotion.settle"),
                        .row("Reduce Motion", "fades only"), .row("Same as", "the tree")),
            ], files: [workspace]),
            SpecElement(number: "1.3", name: "Width", summary: "Drag its edge.", groups: [
                .layout(.row("Width", "300pt ideal, 260 to 640pt, remembered", token: "LayoutTokens.Inspector.idealWidth / minWidth / maxWidth")),
                .behaviour(.row("Handle", "the gutter before the column mirrors the tree's; double-click resets to 300pt", token: "WorkspaceColumnResizeHandle"),
                           .row("JSON", "widens the column to at least 520pt with one spring and returns after; never narrows it", token: "LayoutTokens.Inspector.jsonWidth")),
                .motion(.row("Drag", "one smooth width change, no stepped jumps")),
            ], files: [workspace]),
        ]),
        SpecPart(number: "2", name: "Sections", summary: "Grouped boxes, like System Settings.", elements: [
            SpecElement(number: "2.1", name: "Section header", summary: "An icon, a title and any actions.", groups: [
                .type(.row("Icon", "11pt, secondary"), .row("Title", "13pt semibold, selectable", token: "TypographyTokens.standard"),
                      .row("Subtitle", "optional, 11pt secondary")),
                .layout(.row("Content", "icon · title · actions"), .row("Actions", "small borderless icon-only buttons at the trailing edge"),
                        .row("Gap to the group", "8pt")),
            ], rounds: [r15], files: [section]),
            SpecElement(number: "2.2", name: "Group box", summary: "Rounded rows in an inset box under the header.", groups: [
                .material(.row("Fill", "the workspace group fill", token: "ColorTokens.Workspace.groupFill", swatch: ColorTokens.Workspace.groupFill)),
                .layout(.row("Corner", "10pt continuous", token: "LayoutTokens.FloatingSurface.rowCornerRadius"),
                        .row("Padding", "12pt horizontal, 4pt vertical", token: "LayoutTokens.Inspector.cardPadding / SpacingTokens.xxs")),
            ], rounds: [r15], files: [section]),
            SpecElement(number: "2.3", name: "Row", summary: "A label on the left and a value on the right.", groups: [
                .type(.row("Label", "11pt secondary, one line", token: "TypographyTokens.detail"), .row("Value", "13pt, tabular digits, right-aligned, wraps", token: "TypographyTokens.standard")),
                .layout(.row("Height", "24pt minimum", token: "LayoutTokens.Inspector.rowMinHeight"), .row("Gap", "12pt between label and value", token: "LayoutTokens.Inspector.labelValueGap"),
                        .row("Divider", "between rows, none after the last")),
                .behaviour(.row("Values", "selectable"), .row("Empty", "—"), .row("NULL", "italic, tertiary"),
                           .row("Link row", "the value is accent and opens what it names"), .row("Right-click", "Copy Value")),
            ], files: [section]),
        ]),
        SpecPart(number: "3", name: "What it shows", summary: "The inspector's one job: details of what you pointed at.", elements: [
            SpecElement(number: "3.1", name: "Object details", summary: "The selected object's properties, as sections.", groups: [.behaviour(.row("Shows", "the details of a database object, in InspectorPanelView"))], files: ["Echo/Sources/Features/AppHost/Views/Inspector/InfoSidebar/InfoSidebarView.swift"]),
            SpecElement(number: "3.2", name: "Foreign-key records", summary: "A record and its related records.", groups: [.behaviour(.row("Shows", "the referenced record, with a link symbol, and its related records"))], files: ["Echo/Sources/Features/AppHost/Views/Inspector/InfoSidebar/InfoSidebarView.swift"]),
            SpecElement(number: "3.3", name: "Cell value and JSON", summary: "A selected cell's value; JSON in a viewer that widens the column.", groups: [.behaviour(.row("Cell", "the value, selectable"), .row("JSON", "the JSON viewer, in a column at least 520pt wide"))], files: ["Echo/Sources/Features/AppHost/Views/Inspector/InfoSidebar/InfoSidebarView.swift"]),
            SpecElement(number: "3.4", name: "Nothing selected", summary: "An empty state.", groups: [
                .type(.row("Title", "No Selection, 13pt semibold"), .row("Text", "Select an object, a cell or a row to inspect its details., 13pt secondary")),
            ], files: ["Echo/Sources/Features/AppHost/Views/Inspector/InfoSidebar/InfoSidebarView.swift"]),
            SpecElement(number: "3.5", name: "Read-only extras", summary: "Agent job history and SQL keyword help.", groups: [
                .behaviour(.row("Rule", "configuration stays in the tab; read-only detail may use the inspector")),
            ], files: ["Echo/Sources/Features/AppHost/Views/Inspector/InfoSidebar/InfoSidebarView.swift"]),
        ]),
        SpecPart(number: "4", name: "Notification history", summary: "The bell borrows the column.", elements: [
            SpecElement(number: "4.1", name: "Bell", summary: "Switches the column between details and the notification history.", groups: [
                .behaviour(.row("Click the bell", "the history takes the column; the badge clears; click again to put it away"),
                           .row("Click the inspector button", "from the history it switches the column to the details")),
            ], rounds: ["ongoing.notification-history-r17"], files: [workspace]),
        ]),
    ]
}
