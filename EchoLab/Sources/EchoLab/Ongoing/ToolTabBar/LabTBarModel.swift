import AppKit
import SwiftUI

/// The family a tool tab belongs to (round 37.1); IC2 tints its icon.
enum LabTBarFamily {
    case query, monitor, manage, health, properties, canvas

    var tint: Color {
        switch self {
        case .query: ColorTokens.Text.secondary
        case .monitor: ColorTokens.Status.info
        case .manage: ColorTokens.Status.warning
        case .health: ColorTokens.Status.success
        case .properties: ColorTokens.Text.secondary
        case .canvas: ColorTokens.accent
        }
    }
}

/// A kind of tab with the icon Echo gives it today (WorkspaceTab+KindLabels) and the proposed one.
struct LabTBarKind: Identifiable {
    var id: String { name }
    let name: String
    let today: String
    let proposed: String
    let family: LabTBarFamily

    static let query = LabTBarKind(name: "Query", today: "tablecells", proposed: "chevron.left.forwardslash.chevron.right", family: .query)
    static let jobs = LabTBarKind(name: "Agent Jobs", today: "gearshape", proposed: "calendar.badge.clock", family: .manage)

    /// Every kind of tab, in the order Echo's KindLabels lists them. `today` is read from the code.
    static let all: [LabTBarKind] = [
        query,
        LabTBarKind(name: "Table Structure", today: "wrench.and.screwdriver", proposed: "tablecells.badge.ellipsis", family: .properties),
        LabTBarKind(name: "Schema Diagram", today: "chart.xyaxis.line", proposed: "point.3.connected.trianglepath.dotted", family: .canvas),
        jobs,
        LabTBarKind(name: "psql", today: "terminal", proposed: "terminal", family: .query),
        LabTBarKind(name: "Extension Structure", today: "puzzlepiece.fill", proposed: "puzzlepiece", family: .properties),
        LabTBarKind(name: "Extensions", today: "puzzlepiece", proposed: "puzzlepiece.extension", family: .manage),
        LabTBarKind(name: "Activity Monitor", today: "chart.bar.doc.horizontal", proposed: "gauge.with.dots.needle.67percent", family: .monitor),
        LabTBarKind(name: "Maintenance", today: "wrench.and.screwdriver", proposed: "wrench.and.screwdriver", family: .health),
        LabTBarKind(name: "Extended Events", today: "bolt.horizontal", proposed: "bolt.horizontal", family: .monitor),
        LabTBarKind(name: "Availability Groups", today: "server.rack", proposed: "server.rack", family: .manage),
        LabTBarKind(name: "Database Security", today: "lock.shield", proposed: "lock.shield", family: .manage),
        LabTBarKind(name: "Server Security", today: "lock.shield", proposed: "key", family: .manage),
        LabTBarKind(name: "Advanced Objects (PostgreSQL)", today: "lock.shield", proposed: "cube.transparent", family: .manage),
        LabTBarKind(name: "Advanced Objects (SQL Server)", today: "puzzlepiece.extension", proposed: "shippingbox", family: .manage),
        LabTBarKind(name: "Error Log", today: "doc.text", proposed: "exclamationmark.bubble", family: .health),
        LabTBarKind(name: "SQL Profiler", today: "trace", proposed: "waveform", family: .monitor),
        LabTBarKind(name: "Resource Governor", today: "r.square.on.square", proposed: "gauge.with.needle", family: .manage),
        LabTBarKind(name: "Server Properties", today: "gearshape.2", proposed: "slider.horizontal.3", family: .properties),
        LabTBarKind(name: "Tuning Advisor", today: "wand.and.stars", proposed: "tuningfork", family: .health),
        LabTBarKind(name: "Policy Management", today: "checkmark.seal", proposed: "checkmark.seal", family: .manage),
        LabTBarKind(name: "Schema Diff", today: "doc.on.doc", proposed: "arrow.left.arrow.right.square", family: .canvas),
        LabTBarKind(name: "Query Builder", today: "hammer", proposed: "rectangle.connected.to.line.below", family: .canvas),
    ]

    static func named(_ name: String) -> LabTBarKind { all.first { $0.name == name } ?? query }

    /// Whether macOS 26 has the symbol. A missing one draws nothing in Echo.
    static func exists(_ symbol: String) -> Bool { NSImage(systemSymbolName: symbol, accessibilityDescription: nil) != nil }
}

/// A tab in the strip.
struct LabTBarTab: Identifiable {
    let id: String
    let title: String
    let kind: LabTBarKind
    /// Which server it belongs to (0 or 1); sets the dot's colour.
    let server: Int
    var pages: [String] = []

    var serverColor: Color { server == 0 ? ColorTokens.Status.success : ColorTokens.Status.warning }
}

/// Widths as Echo measures them (TabPageChipsMetrics), at the same 11pt type.
enum LabTBarMetrics {
    static let shortNames: [String: String] = [
        "Event Triggers": "Triggers", "Composite Types": "Composite", "Range Types": "Ranges", "Text Search": "Search",
        "Foreign Data": "Foreign", "Prepared Txns": "Prepared", "Configuration": "Config", "Replication": "Repl",
        "Password Policies": "Passwords", "Advanced Objects": "Advanced", "Data Masking": "Masking", "Tablespaces": "Spaces",
        "Certificates": "Certs",
    ]

    static let chipPadding: CGFloat = SpacingTokens.xs2
    static let compactChipPadding: CGFloat = SpacingTokens.xxs2
    static let chipSpacing: CGFloat = SpacingTokens.xxxs
    /// A tab that shows only its icon.
    static let iconOnlyWidth: CGFloat = 40
    /// A tab with a title shows no less than this before it becomes icon-only.
    static let smallestTitledWidth: CGFloat = 92
    static let maxShare: CGFloat = LayoutTokens.TabPages.maxShareOfStrip

    static func label(_ page: String, compact: Bool) -> String { compact ? (shortNames[page] ?? page) : page }

    static func titleWidth(_ title: String) -> CGFloat {
        ceil((title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 11, weight: .medium)]).width)
    }

    static func chipWidth(_ page: String, compact: Bool) -> CGFloat {
        let text = label(page, compact: compact)
        let width = ceil((text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 11, weight: .semibold)]).width)
        return width + (compact ? compactChipPadding : chipPadding) * 2 + chipSpacing
    }

    static func pagesWidth(_ pages: [String], compact: Bool) -> CGFloat {
        pages.reduce(0) { $0 + chipWidth($1, compact: compact) }
    }

    static var moreWidth: CGFloat { chipWidth("More", compact: false) + SpacingTokens.sm }

    /// Icon, close button, gaps and the hairline around a tab's title and pages.
    static func chrome(icon: Bool) -> CGFloat {
        LayoutTokens.TabPages.tabChrome - (icon ? 0 : SpacingTokens.sm2 + SpacingTokens.xxs2)
    }

    /// The width a tab needs to show its title and every page.
    static func needed(_ tab: LabTBarTab, compact: Bool, icon: Bool) -> CGFloat {
        ceil(titleWidth(tab.title) + pagesWidth(tab.pages, compact: compact) + chrome(icon: icon))
    }
}
