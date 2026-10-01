import SwiftUI

/// Round 37.4 · Tool tabs: a theme per family. Each family from 37.1 drawn in the unified design
/// (37.2's two rows, 37.3's recommended controls, plain tables), with the one layout idea that
/// makes it that family. Echo today has no family themes: each tool lays out its own panes.
@MainActor
enum ToolTabThemesRound {
    static let spec = RoundSpec(
        exhibits: LabTTFamily.allCases.map { family in
            RoundSpec.Exhibit(id: family.rawValue, title: family.rawValue, summary: family.summary,
                              isWide: true, designWidth: 860, designHeight: 440) { _ in
                LabTTFamilyTab(family: family)
            }
        },
        questions: [
            .init(id: "monitor", title: "Monitor",
                  question: "Should every monitor open on figure tiles above its live table, as Activity Monitor does (TLT-3)?",
                  choices: [.init(id: "tiles", name: "MO0 · Yes, tiles first"), .init(id: "table", name: "MO1 · Only where the figures mean something; otherwise the table")],
                  recommended: "table",
                  why: "Activity Monitor's four figures earn their tiles; SQL Profiler and Extended Events would only show an event count, which is the table's own footer."),
            .init(id: "manage", title: "Manage",
                  question: "Where do a selected item's details go?",
                  choices: [
                      .init(id: "pane", name: "MA0 · A details card beside the list (as drawn)"),
                      .init(id: "inspector", name: "MA1 · The inspector column"),
                      .init(id: "sheet", name: "MA2 · Double-click opens the item's sheet; no details pane"),
                  ],
                  recommended: "pane",
                  why: "Agent Jobs and Security already do it, and it keeps the inspector for what you click in any tab; editing still opens the item's sheet."),
            .init(id: "health", title: "Health",
                  question: "Should every finding carry the button that fixes it?",
                  choices: [.init(id: "fix", name: "HE0 · Yes: Fix, Back Up Now, Rebuild"), .init(id: "list", name: "HE1 · No: findings only; fixes from the menus")],
                  recommended: "fix",
                  why: "A health page is a to-do list; the action next to the problem is what makes it useful rather than a report."),
            .init(id: "properties", title: "Properties",
                  question: "How are changes applied?",
                  choices: [
                      .init(id: "bar", name: "PR0 · An Apply bar at the bottom with the number of changes (as drawn)"),
                      .init(id: "instant", name: "PR1 · Each change applies at once"),
                  ],
                  recommended: "bar",
                  why: "Server settings can't be taken back by Undo; batching them with a count and Revert matches the property sheets elsewhere in Echo."),
            .init(id: "canvas", title: "Canvas",
                  question: "Where do a canvas tool's view controls live?",
                  choices: [
                      .init(id: "floating", name: "CA0 · A floating glass bar at the bottom (as drawn)"),
                      .init(id: "header", name: "CA1 · In the toolbar row like every other tool"),
                  ],
                  recommended: "floating",
                  why: "Zoom and layout act on the drawing, so they float over it, like the editor's zoom pill and Maps' controls; the header keeps the actions (Add Table, Export)."),
        ]
    )
}
