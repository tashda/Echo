import SwiftUI

/// The inspector as it is in Echo today: one workspace card in a column on the canvas, with the
/// sections as grouped boxes (round 10 IN1, round 15).
@MainActor
enum InspectorArea {
    static let area = LabArea(
        id: "inspector",
        title: "Inspector",
        symbol: "sidebar.right",
        summary: "A column on the canvas mirroring the tree: Details, Bookmarks and History share one column; details sections are grouped boxes with a header over rounded rows, like System Settings.",
        asBuilt: AsBuiltPage(
            verification: .init(
                level: .code, commit: "9983a13c", date: "2026-10-01",
                note: "Read from WorkspaceInspectorColumn, InfoSidebarView, InspectorSection and InspectorSectionRow, WorkspaceColumnResizeHandle and the Inspector tokens. The specimen is the Echo Labs copy of the grouped-box column."),
            stageHeight: 640,
            behaviours: [
                .init(trigger: "Point at something", result: "The inspector shows what you pointed at: a database object's details, a foreign key's record and related records, a cell value, the JSON viewer, Agent job history, or SQL keyword help."),
                .init(trigger: "Nothing selected", result: "\"No Selection\" and \"Select an object, a cell or a row.\""),
                .init(trigger: "Select text in a value", result: "Values are selectable; right-click a row for Copy Value. A link row opens what it names."),
                .init(trigger: "Show JSON", result: "The column widens to at least 520pt with one spring and returns to the width you chose afterwards; it is never narrowed."),
                .init(trigger: "Toggle the inspector", result: "The column shows or hides with the tree's motion; from library or notifications it switches to Details. View › Bookmarks / Query History and the inspector menu open the library without changing the tree (round 39; awaiting verification)."),
                .init(trigger: "Drag its edge", result: "One smooth width change (no stepped jumps), between 260 and 640pt; double-click the edge to reset to 300pt. The width is remembered."),
                .init(trigger: "Click the bell", result: "The column switches to the notification history and back; the two cross-fade."),
            ],
            motions: [
                .init(name: "Show and hide", curve: "house spring in, smooth out", duration: "0.45s", note: "The same as the tree"),
                .init(name: "Width change", curve: "smooth", duration: "follows the drag"),
            ],
            measurements: [
                .init(label: "Column width", value: "300pt ideal, 260 to 640; JSON at least 520", token: "LayoutTokens.Inspector.idealWidth / minWidth / maxWidth / jsonWidth"),
                .init(label: "Card padding", value: "12pt, single (not doubled)", token: "LayoutTokens.Inspector.cardPadding"),
                .init(label: "Group corner", value: "10pt continuous", token: "LayoutTokens.FloatingSurface.rowCornerRadius"),
                .init(label: "Group fill", value: "the workspace group fill", token: "ColorTokens.Workspace.groupFill"),
                .init(label: "Section header", value: "icon 11pt secondary, title 13pt semibold, optional 11pt subtitle, small borderless icon actions", token: "InspectorSection"),
                .init(label: "Row", value: "label 11pt secondary left, value 13pt tabular digits right; 24pt minimum, 12pt gap, a divider between rows", token: "LayoutTokens.Inspector.rowMinHeight / labelValueGap"),
                .init(label: "Values", value: "empty shows —, NULL is italic tertiary, links are accent"),
            ],
            rules: [
                .init(text: "A column on the canvas, mirroring the tree",
                      why: "The window reads tree, cards, inspector. A floating card, inside the results and the native inspector restyled were rejected.",
                      rounds: ["decided.inspector-column"]),
                .init(text: "Grouped boxes in one card, not a card per section",
                      why: "Stacked shadows were cut off at the column's edges; one card with inset groups avoids it.",
                      rounds: ["ported.Round 15 · inspector"]),
                .init(text: "Details and saved SQL share the column",
                      why: "Round 39 RT2 keeps Bookmarks and History beside the tab without replacing the Explorer; the bell still opens notifications.", rounds: ["ongoing.rail-tools-r39"]),
                .init(text: "Configuration stays in the tab",
                      why: "Read-only detail, such as a job's history, may use the inspector."),
            ],
            code: [
                "Echo/Sources/Features/AppHost/Views/Navigation/WorkspaceView.swift",
                "Echo/Sources/Shared/DesignSystem/Components/InspectorSection.swift",
                "Packages/EchoDesignSystem/Sources/EchoDesignSystem/Tokens/LayoutToken+Inspector.swift",
                "Echo/Sources/Features/AppHost/Views/Inspector/InfoSidebar/InfoSidebarView.swift",
                "Echo/Sources/Features/AppHost/Views/Navigation/WorkspaceInspectorColumn.swift",
                "Echo/Sources/Features/AppHost/Views/Navigation/WorkspaceInspectorPicker.swift",
                "Echo/Sources/Features/QueryWorkspace/Views/Results/QueryHistoryPanelView.swift",
            ]
        ) {
            InspectorLibrarySpecimen()
        },
        spec: InspectorSpec.spec(stageHeight: 640) { InspectorLibrarySpecimen().specAnchor("1.1") }
    )
}
