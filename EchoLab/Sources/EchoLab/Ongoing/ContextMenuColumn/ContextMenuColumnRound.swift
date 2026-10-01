import SwiftUI

/// Round 42.5 · Context menus: columns, routines and the rest. Echo today: a column has no menu
/// (contextMenu(for:) returns nil for `.column`, as for tool rows); a procedure has New Query |
/// Definition, Execute, Modify | Script as › | Tasks › | Drop Procedure; a login has Script as › |
/// Enable or Disable Login | Drop Login | Properties.
@MainActor
enum ContextMenuColumnRound {
    static let spec = RoundSpec(
        exhibits: LabCMExhibits.pair("column", row: ("textformat", ColorTokens.Text.secondary, "uniqueBagID"), today: nil,
                                     todayNote: "Columns have no menu.") { _ in LabCMMenus.columnProposal }
            + LabCMExhibits.pair("procedure", row: ("terminal", ColorTokens.Status.error, "dbo.IndexOptimize"), today: LabCMMenus.procedureToday) { _ in LabCMMenus.procedureProposal }
            + LabCMExhibits.pair("login", row: ("person", Color(nsColor: .systemPurple), "GLOBAL\\kenneth"), today: LabCMMenus.loginToday) { _ in LabCMMenus.loginProposal },
        questions: [
            .init(id: "insert", title: "Insert in Query",
                  question: "Insert in Query puts the column's name at the caret of the front query tab. Worth it?",
                  choices: [.init(id: "yes", name: "IQ0 · Yes, and dragging a column into the editor does the same"), .init(id: "no", name: "IQ1 · No: Copy Name is enough")],
                  recommended: "yes",
                  why: "Writing a SELECT list from the tree is the column menu's main job; it's one step where Copy Name is two."),
            .init(id: "rename", title: "Rename from the tree",
                  question: "Rename a column (or a table) right in the tree?",
                  choices: [.init(id: "inline", name: "RN0 · Yes: the name becomes editable, then Echo shows the ALTER it will run"), .init(id: "sheet", name: "RN1 · Only from Edit Structure")],
                  recommended: "inline",
                  why: "Finder-like renaming is what people try first; showing the statement before running it keeps it safe on production."),
            .init(id: "execute", title: "Execute a procedure",
                  question: "What does Execute open?",
                  choices: [.init(id: "sheet", name: "EX0 · A sheet asking for the parameters, then runs it in a new tab"), .init(id: "script", name: "EX1 · A new tab with EXEC and the parameters to fill in")],
                  recommended: "script",
                  why: "A query tab with the EXEC written out is how SSMS does it, and you can edit or save it; a sheet hides the SQL."),
        ]
    )
}
