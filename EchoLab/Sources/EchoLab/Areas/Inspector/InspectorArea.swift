import SwiftUI

/// The inspector as it is in Echo today: one workspace card in a column on the canvas, with the
/// sections as grouped boxes (round 10 IN1, round 15).
@MainActor
enum InspectorArea {
    static let area = LabArea(
        id: "inspector",
        title: "Inspector",
        symbol: "sidebar.right",
        summary: "A column on the canvas mirroring the tree: one card, sections as grouped boxes with a header over rounded rows, like System Settings.",
        asBuilt: AsBuiltPage(
            verification: .init(
                level: .code, commit: "a24192df", date: "2026-09-30",
                note: "Round 15's grouped boxes were built in commit 755f8254 and await your confirmation in the running app."),
            stageHeight: 640,
            behaviours: [
                .init(trigger: "Point at something", result: "The inspector shows what you pointed at: object details, foreign-key records with related records, a cell value, the JSON viewer, Agent job history, SQL keyword help."),
                .init(trigger: "Select a row", result: "Row-detail mode shows every column of the selected row."),
                .init(trigger: "Select text in a value", result: "Values are selectable."),
                .init(trigger: "Toggle the inspector", result: "The column shows or hides with the tree's motion."),
                .init(trigger: "Drag its edge", result: "One smooth width change (no stepped jumps)."),
                .init(trigger: "Click the bell", result: "The column switches to the notification history; the bell and the inspector button switch it back and forth."),
            ],
            motions: [
                .init(name: "Show and hide", curve: "house spring in, smooth out", duration: "0.45s", note: "The same as the tree"),
                .init(name: "Width change", curve: "smooth", duration: "follows the drag"),
            ],
            measurements: [
                .init(label: "Column padding", value: "12pt single (not doubled)", token: "LayoutTokens.FloatingSurface.padding"),
                .init(label: "Group corner", value: "rounded inset box", token: "LayoutTokens.FloatingSurface.rowCornerRadius"),
                .init(label: "Section header", value: "icon, title, actions"),
                .init(label: "Rows", value: "label left, selectable value right"),
                .init(label: "Group fill", value: "secondary background", token: "ColorTokens.Background.secondary"),
            ],
            rules: [
                .init(text: "A column on the canvas, mirroring the tree",
                      why: "The window reads tree, cards, inspector. A floating card, inside the results and the native inspector restyled were rejected.",
                      rounds: ["decided.inspector-column"]),
                .init(text: "Grouped boxes in one card, not a card per section",
                      why: "Stacked shadows were cut off at the column's edges; one card with inset groups avoids it.",
                      rounds: ["ported.Round 15 · inspector"]),
                .init(text: "One job: details of what you pointed at",
                      why: "Notifications moved to the bell, so the inspector shows details only."),
                .init(text: "Configuration stays in the tab",
                      why: "Read-only detail, such as a job's history, may use the inspector."),
            ],
            code: [
                "Echo/Sources/Features/AppHost/Views/Navigation/WorkspaceView.swift",
                "Echo/Sources/Shared/DesignSystem/Components/InspectorSection.swift",
                "Packages/EchoDesignSystem/Sources/EchoDesignSystem/Tokens/LayoutToken+Inspector.swift",
            ]
        ) {
            LabInspectorColumn(look: .groupedBoxes)
        },
        spec: InspectorSpec.spec(stageHeight: 640) { LabInspectorColumn(look: .groupedBoxes).specAnchor("1.1") }
    )
}
