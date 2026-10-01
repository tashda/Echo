import SwiftUI

/// Round 33.1's choices for the Agent Jobs tab.
enum LabAJHeaders: String, CaseIterable {
    case today = "JH0 · Each pane its own header (today)"
    case unified = "JH1 · One header for every pane"
    var summary: String {
        switch self {
        case .today: "Jobs and History: 13pt semibold, 12pt in, 6pt down. Details: 14pt semibold, 16pt in, 12pt down, its sections centred under it."
        case .unified: "Every pane: 13pt semibold title and a grey count, 12pt in, 10pt down, 36pt tall; actions at the right of the same line."
        }
    }
}

enum LabAJLayout: String, CaseIterable {
    case today = "JL0 · Jobs beside Details, History under both (today)"
    case jobsFull = "JL1 · Jobs the full height on the left; Details over History on the right"
    case historyInDetails = "JL2 · Jobs on the left; History as a fifth section of Details"
    var summary: String {
        switch self {
        case .today: "Three cards; the jobs list gets half the width, so names are cut at about 14 characters."
        case .jobsFull: "The list keeps its whole height (24 jobs without scrolling); history stays under the job it belongs to."
        case .historyInDetails: "Two cards. History is about the selected job, so it sits with the job's other sections."
        }
    }
}

enum LabAJSections: String, CaseIterable {
    case today = "DT0 · Segmented, centred under the title (today)"
    case header = "DT1 · Segmented, at the right of the header line"
    case leading = "DT2 · Segmented under the title, at the leading edge"
}

enum LabAJColumns: String, CaseIterable {
    case today = "JC0 · Enabled, Name, Owner, Category, Status (today)"
    case compact = "JC1 · Status, Name, Last run, Next run"
    var summary: String {
        switch self {
        case .today: "Owner and Category are the same for almost every job (sa, Database Maintenance), and push the name to about 14 characters."
        case .compact: "One status symbol (enabled, running, failed, disabled), then what you look for: when it last ran and when it runs next. Owner and category move to Properties."
        }
    }
}

enum LabAJEmptyRows: String, CaseIterable {
    case today = "ER0 · Grey stripes fill the empty part of a list (today)"
    case plain = "ER1 · Plain white below the last row"
}

struct LabAJLook {
    var headers: LabAJHeaders, layout: LabAJLayout, sections: LabAJSections, columns: LabAJColumns, empty: LabAJEmptyRows
    static let today = LabAJLook(headers: .today, layout: .today, sections: .today, columns: .today, empty: .today)

    @MainActor static func from(_ v: RoundValues) -> LabAJLook {
        LabAJLook(headers: .init(rawValue: v["headers"]) ?? .unified, layout: .init(rawValue: v["layout"]) ?? .jobsFull,
                  sections: .init(rawValue: v["sections"]) ?? .today, columns: .init(rawValue: v["columns"]) ?? .compact,
                  empty: .init(rawValue: v["empty"]) ?? .plain)
    }
}

/// A job from the owner's server, as the list shows it.
struct LabAJJob: Hashable {
    enum State { case idle, running, disabled, failed }
    let name: String
    let category: String
    let state: State
    let lastRun: String
    let nextRun: String

    static let samples: [LabAJJob] = [
        .init(name: "Cleanup SafepointDB..Safepoint", category: "[Uncategorized]", state: .idle, lastRun: "Today 06:00", nextRun: "Tomorrow 06:00"),
        .init(name: "CommandLog Cleanup", category: "Database Maintenance", state: .idle, lastRun: "Sun 00:00", nextRun: "Sun 00:00"),
        .init(name: "Daily SQL Job status report", category: "[Uncategorized]", state: .idle, lastRun: "Today 07:00", nextRun: "Tomorrow 07:00"),
        .init(name: "DatabaseBackup - USER_DATABASES - LOG", category: "Database Maintenance", state: .running, lastRun: "Running 0:42", nextRun: "15:45"),
        .init(name: "DatabaseBackup - USER_DATABASES - FULL", category: "Database Maintenance", state: .disabled, lastRun: "Sep 26 23:00", nextRun: "Disabled"),
        .init(name: "DatabaseBackup - USER_DATABASES - DIFF", category: "Database Maintenance", state: .disabled, lastRun: "Sep 30 23:00", nextRun: "Disabled"),
        .init(name: "DatabaseIntegrityCheck - SYSTEM_DATABASES", category: "Database Maintenance", state: .idle, lastRun: "Sat 23:00", nextRun: "Sat 23:00"),
        .init(name: "DatabaseIntegrityCheck - USER_DATABASES", category: "Database Maintenance", state: .idle, lastRun: "Sat 23:00", nextRun: "Sat 23:00"),
        .init(name: "IndexOptimize - USER_DATABASES", category: "Database Maintenance", state: .failed, lastRun: "Today 02:00", nextRun: "Tomorrow 02:00"),
        .init(name: "Output File Cleanup", category: "Database Maintenance", state: .idle, lastRun: "Sun 00:00", nextRun: "Sun 00:00"),
        .init(name: "PowerShell_Copy_Sync_Logins", category: "Database Maintenance", state: .running, lastRun: "Running 3:10", nextRun: "16:00"),
        .init(name: "sp_WhoIsActive", category: "[Uncategorized]", state: .disabled, lastRun: "Aug 12 09:00", nextRun: "Disabled"),
    ]

    var symbol: (String, Color) {
        switch state {
        case .idle: ("checkmark.circle.fill", ColorTokens.Status.success)
        case .running: ("arrow.triangle.2.circlepath", ColorTokens.Status.warning)
        case .disabled: ("pause.circle", ColorTokens.Text.tertiary)
        case .failed: ("xmark.circle.fill", ColorTokens.Status.error)
        }
    }

    var statusWord: String {
        switch state {
        case .idle: "Idle"
        case .running: "Running"
        case .disabled: "Idle"
        case .failed: "Idle"
        }
    }
}
