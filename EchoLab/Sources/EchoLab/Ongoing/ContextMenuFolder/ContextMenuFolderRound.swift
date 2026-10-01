import SwiftUI

/// Round 42.6 · Context menus: folders and sections. Echo today: Tables has Refresh | New Table,
/// New Table (SQL) (objectGroupMenu); the server's Security has Refresh, New Login | Open Security
/// Management; Agent Jobs has Refresh | Open in Tab, Open in New Window (serverFolderMenu).
@MainActor
enum ContextMenuFolderRound {
    static let spec = RoundSpec(
        exhibits: LabCMExhibits.pair("tables", row: ("tablecells", Color(nsColor: .systemTeal), "Tables"), today: LabCMMenus.tablesFolderToday) { _ in LabCMMenus.tablesFolderProposal }
            + LabCMExhibits.pair("security", row: ("lock.shield", Color(nsColor: .systemPurple), "Security"), today: LabCMMenus.securityFolderToday) { _ in LabCMMenus.securityFolderProposal }
            + LabCMExhibits.pair("jobs", row: ("clock", ColorTokens.accent, "Agent Jobs"), today: LabCMMenus.jobsFolderToday) { _ in LabCMMenus.jobsFolderProposal },
        questions: [
            .init(id: "first", title: "A folder's first item",
                  question: "Should a folder's menu start with its overview tab where it has one (Security Overview, Agent Jobs Overview), and with New otherwise?",
                  choices: [.init(id: "yes", name: "FF0 · Yes"), .init(id: "new", name: "FF1 · New first, always")],
                  recommended: "yes",
                  why: "It matches round 38's first row in the folder: the menu and the tree say the same thing in the same order."),
            .init(id: "filter", title: "Filter",
                  question: "Add Filter Tables (type to narrow the folder in place) to object folders?",
                  choices: [.init(id: "yes", name: "FL0 · Yes, in every object folder"), .init(id: "no", name: "FL1 · No: the toolbar search covers it")],
                  recommended: "yes",
                  why: "A database with 800 tables needs it; SSMS's Filter is one of its most used folder commands. It narrows only this folder, which the global search can't."),
            .init(id: "empty", title: "Empty space",
                  question: "Right-clicking empty space in the tree: what should it offer?",
                  choices: [.init(id: "connection", name: "ES0 · New Connection, Refresh All Servers, Show Empty Folders"), .init(id: "none", name: "ES1 · Nothing")],
                  recommended: "connection",
                  why: "Finder offers New Folder in empty space; the tree's equivalent is a new connection, and the view toggle is easier to find there than in Settings."),
        ]
    )
}
