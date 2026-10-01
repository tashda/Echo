import SwiftUI

/// Round 42.1 · Context menus: the rules. Echo today: every menu is built by hand in
/// ObjectBrowserSidebarView+ContextMenus, +ServerMenus, +DatabaseMenus and +ObjectMenus. A table's has
/// five groups (New Query | Data, Structure, Diagram | Script as | Tasks | Drop Table | Properties);
/// items carry symbols in code but showed none in the owner's screenshot; there is no title, no
/// Copy Name, and columns and tool rows have no menu at all. The rules below come from Apple's
/// Human Interface Guidelines › Context menus (read 2026-10-01): only what's relevant, few items, about
/// three groups, the most used first, one level of submenus, hide what doesn't apply, no keyboard
/// shortcuts, destructive items last and marked, familiar icons, a title only when it clarifies.
@MainActor
enum ContextMenuAnatomyRound {
    static let spec = RoundSpec(
        controls: [
            .of("icons", "Icons", LabCMRules.Icons.self, default: .familiar,
                question: "Compare the menus with no icons, familiar ones and all of them. Which scans fastest?",
                recommend: .familiar,
                why: "Apple: use the system's icons for familiar actions (Copy, Delete, Info). Icons on every item turn into a column of pictures nobody reads (what is the icon for Diagram?), and none at all loses the quick landmarks: the trash, the info circle."),
            .of("properties", "Properties and Drop", LabCMRules.Properties.self, default: .lastAfterDrop,
                question: "Where should Properties and Drop sit? Open the menu near the bottom of the screen and near the top.",
                recommend: .lastAfterDrop,
                why: "Your instinct and SSMS's habit: Properties is the last item, where a quick flick of the pointer lands. Drop in its own group above it is out of the way of that flick; Drop on the bottom edge is the worst place for it with a mouse.",
                summary: \.summary),
            .of("title", "Title", LabCMTitle.self, default: .name,
                question: "Should the menu name what you right-clicked?",
                recommend: .name,
                why: "Apple suggests a title only when it clarifies the target; in a dense tree the menu often covers the row you clicked, so dbo.at_tbl at the top confirms what Drop Table will drop."),
            .of("copyName", "Copy Name", LabCMCopyName.self, default: .yes,
                question: "Should every object's menu have Copy Name?",
                recommend: .yes,
                why: "Copying a table's or column's name to paste into a query or a chat is one of the most common reasons to right-click in a database tool (DataGrip and SSMS have it); today Echo has no way to do it."),
            .of("drop", "Drop", LabCMDrop.self, default: .plain,
                question: "Should Drop be red?",
                recommend: .plain,
                why: "On the Mac, Finder's Move to Trash and Mail's Delete are plain text; red is the iPhone and iPad convention. Its own group, the trash icon and the confirmation that follows are enough."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today: a table", summary: "As in your screenshot.", isEchoToday: true, isWide: true, designWidth: 640, designHeight: 470) { _ in
                LabCMScene(row: ("tablecells", Color(nsColor: .systemTeal), "dbo.at_tbl"), groups: LabCMMenus.tableToday, rules: .today)
            },
            .init(id: "table", title: "Proposal: a table", summary: "Built from the controls.", isWide: true, designWidth: 640, designHeight: 470) { values in
                let rules = LabCMRules.from(values)
                LabCMScene(row: ("tablecells", Color(nsColor: .systemTeal), "dbo.at_tbl"), groups: rules.arrange(LabCMMenus.tableProposal(names: .verbs)), rules: rules, title: "dbo.at_tbl")
            },
            .init(id: "database", title: "Proposal: a database", summary: "The same rules on the longest menu.", isWide: true, designWidth: 640, designHeight: 470) { values in
                let rules = LabCMRules.from(values)
                LabCMScene(row: ("cylinder", ColorTokens.Status.info, "ccsLDK17"), groups: rules.arrange(LabCMMenus.databaseProposal(backUpOnTop: true)), rules: rules, title: "ccsLDK17")
            },
        ],
        questions: [
            .init(id: "order", title: "One order for every menu",
                  question: "Every menu in the same order: open and create; copy, script and tasks; refresh; then Drop and Properties. Agree?",
                  choices: [.init(id: "yes", name: "MO0 · Yes, one order everywhere"), .init(id: "per", name: "MO1 · No, each menu ordered by how often its items are used")],
                  recommended: "yes",
                  why: "Apple asks for consistency across an app; one order means your hand learns where Refresh and Properties are once, for every object."),
            .init(id: "disabled", title: "Commands that don't apply",
                  question: "A command that doesn't apply (Execute on a view): hidden or dimmed?",
                  choices: [.init(id: "hide", name: "HD0 · Hidden"), .init(id: "dim", name: "HD1 · Dimmed")],
                  recommended: "hide",
                  why: "Apple: hide unavailable items in context menus (only Cut, Copy and Paste may be dimmed); the main menus are where people discover what exists."),
            .init(id: "menuBar", title: "The same commands in the menu bar",
                  question: "Apple asks that every context menu command is also in the main menus. Add an Object menu to the menu bar for the selected item?",
                  choices: [.init(id: "yes", name: "MB0 · Yes: an Object menu (New Query, Open Data, Script as, Properties, Drop…)"), .init(id: "later", name: "MB1 · Later")],
                  recommended: "yes",
                  why: "It's where keyboard shortcuts live (they don't belong in context menus) and where people look when they don't know to right-click."),
        ],
        presets: [.init(id: "recommended", name: "My recommendation", values: ["icons": LabCMRules.Icons.familiar.rawValue, "properties": LabCMRules.Properties.lastAfterDrop.rawValue,
                                                                             "title": LabCMTitle.name.rawValue, "copyName": LabCMCopyName.yes.rawValue, "drop": LabCMDrop.plain.rawValue],
                          isRecommended: true)]
    )
}
