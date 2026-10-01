import SwiftUI

/// Round 42.4 · Context menus: tables and views. Echo today (objectMenu): a table has New Query |
/// Data, Structure, Diagram | Script as › | Tasks › (Generate Scripts, Import Data, Enable System
/// Versioning) | Drop Table | Properties; a view has New Query | Data, Definition | Script as › |
/// Tasks › | Drop View, and no Properties.
@MainActor
enum ContextMenuTableRound {
    static let spec = RoundSpec(
        controls: [
            .of("names", "Words", LabCMTableNames.self, default: .verbs,
                question: "Compare Data / Structure with Open Data / Edit Structure.",
                recommend: .verbs,
                why: "A menu item is a command: 'Data' could mean many things, 'Open Data' says what happens. Apple's menu guidelines ask for verbs."),
        ],
        exhibits: LabCMExhibits.pair("table", row: ("tablecells", Color(nsColor: .systemTeal), "dbo.at_tbl"), today: LabCMMenus.tableToday, openSubmenu: "Script as") { values in
            LabCMMenus.tableProposal(names: LabCMTableNames(rawValue: values["names"]) ?? .verbs)
        } + [
            .init(id: "viewToday", title: "Echo today: a view", summary: "No Properties.", isEchoToday: true, isWide: true, designWidth: 640, designHeight: 470) { _ in
                LabCMScene(row: ("eye", Color(nsColor: .systemIndigo), "dbo.v_bags"), groups: LabCMMenus.viewToday, rules: .today)
            },
        ],
        questions: [
            .init(id: "openDefault", title: "Double-click",
                  question: "What does double-clicking a table do?",
                  choices: [.init(id: "data", name: "DC0 · Open Data (the first item in its menu)"), .init(id: "expand", name: "DC1 · Expand its columns")],
                  recommended: "data",
                  why: "Finder's rule: double-click does the menu's first item. The disclosure chevron already expands."),
            .init(id: "truncate", title: "Truncate",
                  question: "Add Truncate Table (in Tasks, with a confirmation)?",
                  choices: [.init(id: "yes", name: "TR0 · Yes"), .init(id: "no", name: "TR1 · No")],
                  recommended: "yes",
                  why: "SSMS and DataGrip both offer it; it's what people use to empty a staging table without dropping it."),
            .init(id: "view", title: "Views",
                  question: "Should a view's menu be the table's menu with Definition in place of Structure (and Properties added)?",
                  choices: [.init(id: "same", name: "VW0 · Yes, the same shape"), .init(id: "own", name: "VW1 · Its own")],
                  recommended: "same",
                  why: "You read a view like a table; one shape for both is one thing to learn."),
        ]
    )
}
