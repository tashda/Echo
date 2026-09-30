import SwiftUI

/// Round 17: how the notification history looks in the inspector's column, and how a
/// notification opens to its whole message.
enum LabNHStyle: String, CaseIterable, Identifiable {
    case timeline = "A · Timeline"
    case cards = "B · Cards"
    case listDetail = "C · List and detail"
    case compactCards = "D · Compact cards"
    case attentionFirst = "E · Attention first"
    case stacked = "F · Stacked by server"
    var id: String { rawValue }

    var summary: String {
        switch self {
        case .timeline: "One quiet list on a time line: a dot in the event's colour, the title, server and time. A click grows the row to the whole message in a selectable block."
        case .cards: "Each event is its own small rounded box, like Notification Center. A click grows the box; errors carry a thin red edge."
        case .listDetail: "Compact one-line rows on top; the selected event's whole message fills the bottom of the column, like Mail. Best for long errors."
        case .compactCards: "B's cards on one line each (icon, title, time), closer together. A click grows the card to the message; nothing is repeated."
        case .attentionFirst: "Errors that haven't been looked at stay pinned at the top as cards; everything else is a quiet list below."
        case .stacked: "Like Notification Center: a server's events stack into one card with \"2 more\"; a click fans the stack out."
        }
    }
}

/// Round 17b: how the header shows the unread count and Clear.
enum LabNHHeaderStyle: String, CaseIterable, Identifiable {
    case accentText = "H1 · Accent text (today)"
    case quietCount = "H2 · Quiet count, Clear on hover"
    case titleMenu = "H3 · Count by the title, one menu"
    case iconButtons = "H4 · Icon buttons"
    case smallButtons = "H5 · Small buttons"
    var id: String { rawValue }

    var summary: String {
        switch self {
        case .accentText: "\"2 new\" and Clear in the accent colour, as in Echo now."
        case .quietCount: "The count is a grey number in a capsule; Clear appears only while the pointer is over the header."
        case .titleMenu: "The count sits quietly beside the title; filters and Clear share one ⋯ menu."
        case .iconButtons: "Filter and Clear as plain icons (a funnel and a trash can), with tooltips; the count is grey."
        case .smallButtons: "Filter and Clear as small native bordered buttons; the count is grey."
        }
    }
}

/// Round 17b: how Open Tab and Copy look on an opened notification.
enum LabNHActionStyle: String, CaseIterable, Identifiable {
    case textLinks = "A1 · Text links (today)"
    case smallButtons = "A2 · Small buttons"
    case glass = "A3 · Glass capsules"
    case icons = "A4 · Icons"
    case menu = "A5 · One ⋯ menu"
    var id: String { rawValue }

    var summary: String {
        switch self {
        case .textLinks: "Accent text links, as in Echo now."
        case .smallButtons: "Small native bordered buttons, like Mail's and Finder's inline actions."
        case .glass: "Small Liquid Glass capsules."
        case .icons: "Icons only (open, copy) with tooltips, quiet until hovered."
        case .menu: "One ⋯ button holding Open Tab, Copy and Copy Details."
        }
    }
}

extension EnvironmentValues {
    @Entry var labNHHeaderStyle: LabNHHeaderStyle = .accentText
    @Entry var labNHActionStyle: LabNHActionStyle = .textLinks
}

enum LabNHGrouping: String, CaseIterable, Identifiable {
    case time = "By time"
    case server = "By server"
    var id: String { rawValue }
}

enum LabNHExpandMotion: String, CaseIterable, Identifiable {
    case grow = "Grow"
    case fade = "Fade in"
    var id: String { rawValue }
}

struct LabNHNotice: Identifiable, Equatable {
    enum Kind { case success, error, warning, info }

    let id: String
    let kind: Kind
    let title: String
    let message: String
    let server: String
    let time: String
    let day: String
    var link: String?
    var isUnread = false

    var symbol: String {
        switch kind {
        case .success: "checkmark.circle.fill"
        case .error: "exclamationmark.octagon.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        }
    }

    var tint: Color {
        switch kind {
        case .success: ColorTokens.Status.success
        case .error: ColorTokens.Status.error
        case .warning: ColorTokens.Status.warning
        case .info: ColorTokens.Text.secondary
        }
    }

    static let samples: [LabNHNotice] = [
        LabNHNotice(id: "q1", kind: .error, title: "Query 1 failed", message: "Query Error: relation \"public.employees\" does not exist\nLINE 2: from public.employees\n             ^\nHINT: Perhaps you meant to reference the table \"employees.employee\".", server: "postgres18", time: "now", day: "Today", link: "Open Tab", isUnread: true),
        LabNHNotice(id: "b1", kind: .error, title: "Backup failed for sales", message: "BACKUP DATABASE is terminating abnormally. Operating system error 5 (Access is denied.) while writing to /var/opt/mssql/backup/sales_2026-09-30.bak. Check that the SQL Server service account can write to the folder.", server: "Test MSSQL", time: "4 min ago", day: "Today", link: "Show Server", isUnread: true),
        LabNHNotice(id: "c1", kind: .success, title: "Connected to Test MSSQL", message: "mssql25 · SQL Server 2025 (17.0.1000.7) · 14 ms", server: "Test MSSQL", time: "12 min ago", day: "Today", link: "Show Server"),
        LabNHNotice(id: "j1", kind: .success, title: "Job completed: Nightly ETL", message: "Nightly ETL finished in 3 min 12 s. 4 steps, 1.2 M rows loaded into dwh.fact_sales.", server: "Test MSSQL", time: "1 h ago", day: "Today"),
        LabNHNotice(id: "w1", kind: .warning, title: "Slow query on employees", message: "Query 2 ran for 42 s. The plan shows a sequential scan on employees.salary (2.8 M rows).", server: "postgres18", time: "Yesterday 17:40", day: "Yesterday", link: "Open Tab"),
        LabNHNotice(id: "s1", kind: .info, title: "Switched to sales", message: "Query 2 now runs against sales.", server: "tippr", time: "Yesterday 09:12", day: "Yesterday"),
    ]
}

/// Sizes of the mock column.
enum LabNHMetrics {
    static let columnWidth: CGFloat = 300
    static let columnHeight: CGFloat = 620
    static let timelineRail: CGFloat = SpacingTokens.md
    static let errorEdge: CGFloat = 3
    static let detailHeight: CGFloat = 240
}
