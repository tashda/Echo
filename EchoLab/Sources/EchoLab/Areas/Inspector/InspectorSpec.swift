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
                .layout(.row("Padding", "12pt, single (not doubled)", token: "LayoutTokens.FloatingSurface.padding"),
                        .row("Why one card", "stacked shadows were cut off at the column's edges")),
            ], rounds: [column, r15], files: [workspace]),
            SpecElement(number: "1.2", name: "Show and hide", summary: "The inspector button toggles the column.", groups: [
                .motion(.row("Show", "house spring, 0.45s"), .row("Hide", "smooth, 0.45s"), .row("Same as", "the tree")),
            ], files: [workspace]),
            SpecElement(number: "1.3", name: "Width", summary: "Drag its edge.", groups: [
                .motion(.row("Drag", "one smooth width change, no stepped jumps")),
            ], files: [workspace]),
        ]),
        SpecPart(number: "2", name: "Sections", summary: "Grouped boxes, like System Settings.", elements: [
            SpecElement(number: "2.1", name: "Section header", summary: "An icon, a title and any actions.", groups: [
                .layout(.row("Content", "icon · title · actions")),
            ], rounds: [r15], files: [section]),
            SpecElement(number: "2.2", name: "Group box", summary: "Rounded rows in an inset box under the header.", groups: [
                .material(.row("Fill", "secondary background", token: "ColorTokens.Background.secondary", swatch: ColorTokens.Background.secondary)),
                .layout(.row("Corner", "rounded inset box", token: "LayoutTokens.FloatingSurface.rowCornerRadius")),
            ], rounds: [r15], files: [section]),
            SpecElement(number: "2.3", name: "Row", summary: "A label on the left and a value on the right.", groups: [
                .behaviour(.row("Values", "selectable")),
            ], files: [section]),
        ]),
        SpecPart(number: "3", name: "What it shows", summary: "The inspector's one job: details of what you pointed at.", elements: [
            SpecElement(number: "3.1", name: "Object details", summary: "The selected object's properties.", groups: [.behaviour(.row("Shows", "details of the object you selected in the tree"))]),
            SpecElement(number: "3.2", name: "Foreign-key records", summary: "A record and its related records.", groups: [.behaviour(.row("Shows", "the referenced record, with related records"))]),
            SpecElement(number: "3.3", name: "Cell value and JSON", summary: "A selected cell's value; JSON in a viewer.", groups: [.behaviour(.row("Shows", "the value, selectable; the JSON viewer for JSON"))]),
            SpecElement(number: "3.4", name: "Row detail", summary: "Every column of the selected row.", groups: [.behaviour(.row("Mode", "row-detail mode"))]),
            SpecElement(number: "3.5", name: "Read-only extras", summary: "Agent job history and SQL keyword help.", groups: [
                .behaviour(.row("Rule", "configuration stays in the tab; read-only detail may use the inspector")),
            ]),
        ]),
        SpecPart(number: "4", name: "Notification history", summary: "The bell borrows the column.", elements: [
            SpecElement(number: "4.1", name: "Bell", summary: "Switches the column between details and the notification history.", groups: [
                .behaviour(.row("Click the bell", "the history takes the column; the badge clears; click again to put it away"),
                           .row("Click the inspector button", "from the history it switches the column to the details")),
            ], rounds: ["ongoing.notification-history-r17"], files: [workspace]),
        ]),
    ]
}
