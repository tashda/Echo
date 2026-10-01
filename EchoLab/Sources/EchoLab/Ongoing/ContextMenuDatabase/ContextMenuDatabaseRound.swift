import SwiftUI

/// Round 42.3 · Context menus: database. Echo today (databaseMenu, SQL Server): Refresh Schema,
/// New Query | Maintenance | Advanced Objects ›, Tasks › (Back Up, Restore | Shrink | Take Offline |
/// Detach | Generate Scripts, Import Flat File, Migrate Data, Visual Query Builder | Data-tier
/// Application Tasks) | Drop Database | Properties.
@MainActor
enum ContextMenuDatabaseRound {
    enum BackUp: String, CaseIterable {
        case inTasks = "BU0 · Back Up and Restore inside Tasks (today)"
        case onTop = "BU1 · Back Up and Restore in the menu itself"
    }

    static let spec = RoundSpec(
        controls: [
            .of("backUp", "Back Up", BackUp.self, default: .onTop,
                question: "Should Back Up and Restore be one click, or inside Tasks?",
                recommend: .onTop,
                why: "They are the most used database tasks by far (SSMS users go Tasks › Back Up hundreds of times); Shrink, Detach and Data-tier stay in Tasks where a rare click is fine."),
        ],
        exhibits: LabCMExhibits.pair("database", row: ("cylinder", ColorTokens.Status.info, "ccsLDK17"), today: LabCMMenus.databaseToday, openSubmenu: "Tasks") { values in
            LabCMMenus.databaseProposal(backUpOnTop: (BackUp(rawValue: values["backUp"]) ?? .onTop) == .onTop)
        },
        questions: [
            .init(id: "queryBuilder", title: "Visual Query Builder",
                  question: "Visual Query Builder is in Tasks today. Where does it belong?",
                  choices: [.init(id: "top", name: "QB0 · Beside New Query and Diagram, as Query Builder"), .init(id: "tasks", name: "QB1 · In Tasks")],
                  recommended: "top",
                  why: "It opens a tab to write a query, like New Query; Tasks is for things done to the database."),
            .init(id: "advanced", title: "Advanced Objects",
                  question: "Advanced Objects (Change Tracking, CDC, Full-Text, Replication) is a submenu of four tabs. Keep it?",
                  choices: [.init(id: "tool", name: "AO0 · Fold it into Open Tool with Maintenance and Security Overview"), .init(id: "keep", name: "AO1 · Keep its own submenu")],
                  recommended: "tool",
                  why: "They are tool tabs like Maintenance; one Open Tool submenu holds them all, and the menu loses a group."),
        ]
    )
}
