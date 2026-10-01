import SwiftUI

/// Round 26: what a tab's content does while the tree or inspector slides.
enum LabCDSMode: String, CaseIterable {
    case live = "A · Reflow live"
    case holdThenSettle = "B · Hold, settle at the end"
    case settleFirst = "C · Settle first, then slide"

    var summary: String {
        switch self {
        case .live: "Echo today: the table re-lays out every cell on every frame of the slide."
        case .holdThenSettle: "The content keeps its width while the card's edge slides, then reflows once when the slide ends."
        case .settleFirst: "The content takes its new width at once, then the card's edge slides to meet it."
        }
    }
}

/// How many rows the sample table holds.
enum LabCDSRows: String, CaseIterable {
    case some = "40 rows"
    case many = "400 rows"

    var count: Int { self == .some ? 40 : 400 }
}

/// One row of the Activity Monitor's sessions table, sample data.
struct LabCDSSession: Identifiable {
    let id: Int
    let login: String
    let database: String
    let status: String
    let command: String
    let cpu: Int
    let reads: Int
    let wait: String

    static func samples(_ count: Int) -> [LabCDSSession] {
        let logins = ["sa", "app_reader", "etl_service", "reporting", "NT AUTHORITY\\SYSTEM"]
        let databases = ["AdventureWorks2022", "master", "WideWorldImporters", "tempdb"]
        let statuses = ["running", "sleeping", "suspended", "background"]
        let commands = ["SELECT", "AWAITING COMMAND", "INSERT", "UPDATE", "TASK MANAGER"]
        let waits = ["—", "PAGEIOLATCH_SH", "LCK_M_S", "CXPACKET", "ASYNC_NETWORK_IO"]
        return (0..<count).map { index in
            LabCDSSession(id: 51 + index, login: logins[index % logins.count], database: databases[index % databases.count],
                          status: statuses[index % statuses.count], command: commands[index % commands.count],
                          cpu: (index * 37) % 9_000, reads: (index * 911) % 250_000, wait: waits[index % waits.count])
        }
    }
}
