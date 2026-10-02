import SwiftUI

/// Round 49: how all of a tool's pages fit in its tab (replaces round 36.2's OF1, the More menu).
enum LabTBarFit: String, CaseIterable {
    case more = "FP0 · Pages that don't fit go into a More menu (today)"
    case grow = "FP1 · The tool tab grows to hold every page; the other tabs shrink to their icons"
    case row = "FP2 · The pages leave the tab for a row of their own under the strip"
    case compact = "FP3 · FP1 with tighter pages and shorter names (Triggers, Config)"
    case adaptive = "FP4 · FP3, and when even that does not fit the window, the pages take a row under the strip"

    var summary: String {
        switch self {
        case .more: "Pages hide behind a menu; the longest tools hide most of their pages."
        case .grow: "Every page shows at full length; it needs a wide window for the long tools."
        case .row: "The tab stays a normal tab; the pages get the whole window's width on a second line."
        case .compact: "Pages at 6pt padding and a few names shortened; fits a 13-inch window for all but one tool."
        case .adaptive: "Always inside the tab when it can be; never hidden when it cannot. Only a very narrow window or a 13-page tool moves them."
        }
    }

    var usesCompactPages: Bool { self == .compact }  // .adaptive resolves to .compact or .row before drawing
}

/// How the strip moves when you click another tab.
enum LabTBarMotion: String, CaseIterable {
    case today = "MO0 · The house spring: every tab's width bounces, titles re-flow, pages fade in late (today)"
    case calm = "MO1 · One smooth curve, no bounce; titles keep their shape and are clipped, never squeezed"
    case glide = "MO2 · MO1, and the white plate glides from tab to tab as one shape"
    case staged = "MO3 · MO2, in order: pages fold away, the plate glides, pages unfold"
    case anchored = "MO4 · MO2 with the icon and title fixed to the tab's left edge: they ride with the tab and never slide inside it"
    case printed = "MO5 · MO2 with the icon and title printed in place: they take their final position at once; only the plate and the tab edges move"

    /// The motions added in revision 2, after the owner found the icon and title moving inside the tab.
    case frozen = "MO6 · MO2 with the icon and title frozen: no position, colour or weight animates; they ride rigidly with the tab's left edge"
    case layer = "MO7 · MO2 with the icons and titles on a layer of their own at their final positions; the tabs and plate glide beneath them"

    case steady = "MO8 · MO4 exactly, with the icon (and title) at the same inset on every tab, so the icon never moves inside its tab"

    case stillIcons = "MO9 · MO8, with the icons on a still layer: each icon is already at its final place, the titles ride with their tabs"

    static let revision2: [LabTBarMotion] = [.anchored, .printed]
    /// Added in revision 4: MO4's animation, with nothing moving inside the tab.
    static let revision4: [LabTBarMotion] = [.steady]
    /// Added in revision 5: the icon still travelled with its tab when a tool tab and a regular tab swap widths.
    static let revision5: [LabTBarMotion] = [.stillIcons]
    /// Added in revision 3: the icon was still travelling into place in every motion above.
    static let revision3: [LabTBarMotion] = [.frozen, .layer]

    var summary: String {
        switch self {
        case .today: "The spring overshoots, so tabs grow past their width and settle back; titles truncate to 'Mainten…' on the way."
        case .calm: "Widths follow a critically damped curve; text never changes size or wraps while it moves."
        case .glide: "The selection is one thing that travels, as in the system's segmented controls."
        case .staged: "The slowest and the most deliberate: three short beats instead of one."
        case .anchored: "Every title is left-aligned at the same inset (inactive tabs lose today's centring), so a tab's words move only as far as its edge does."
        case .steady: "MO4's motion, which you liked, with one change: in MO4 the icon sat 12pt from the edge on the front tab and 14pt on the others, so it slid 2pt when a tab changed. Now it is 14pt on every tab."
        case .stillIcons: "MO8's motion for the tabs and titles, and the icons do not travel at all: they jump to where they will be, and the tabs glide past them. Answers 'the icon still animates when I go from a tool tab to a regular tab'."
        case .frozen: "Nothing about the icon or the title is animated: not where they sit in the tab, not their colour or weight when the tab becomes active. Only the tab's width and the plate move."
        case .layer: "The strictest 'printed on': the labels do not follow their tab as it resizes. They are already where they will end, and the plate and the tab edges sweep over them."
        case .printed: "The words do not travel at all: they are already where they will be, and the plate and the tab edges sweep over and past them."
        }
    }
}

/// The icon on a tab.
enum LabTBarIcons: String, CaseIterable {
    case today = "IC0 · Echo's icons today"
    case literal = "IC1 · A new set: one icon per tool, none repeated, in grey"
    case family = "IC2 · IC1 tinted by the tool's family (Monitor, Manage, Health, Properties, Canvas)"
    case active = "IC3 · IC1 on the active tab only; the others are words"
    case none = "IC4 · No icons: the title alone"

    var summary: String {
        switch self {
        case .today: "Four tools share the lock shield or the wrench; the Profiler's symbol does not exist on macOS 26 and draws nothing."
        case .literal: "Each tool has its own picture, taken from what it does."
        case .family: "The colour says which family the tool belongs to (round 37.1), so related tabs sit together at a glance."
        case .active: "The strip is quiet: the icon marks where you are, and every other tab is its word."
        case .none: "The most room for pages and the calmest strip; kinds are told apart by their words."
        }
    }
}

/// The server dot on a tab (round 30.1, CO2).
enum LabTBarTabDot: String, CaseIterable {
    case keep = "SD0 · A dot of the server's colour on every tab (today)"
    case several = "SD1 · A dot only while tabs of two or more servers are open"
    case remove = "SD2 · No dot; the tooltip and the window's header say which server"

    var summary: String {
        switch self {
        case .keep: "Always there, even with one server open, where it says nothing."
        case .several: "Appears only when it carries information."
        case .remove: "One thing less in every tab, and 8pt back."
        }
    }
}

/// The server dot in the results footer's server / database pill (round 30.1, CO2).
enum LabTBarPillDot: String, CaseIterable {
    case keep = "PD0 · A dot before the server's name (today)"
    case remove = "PD1 · No dot; the pill is its words"
}

/// Advanced Objects on PostgreSQL has thirteen pages, the most of any tool.
enum LabTBarAdvanced: String, CaseIterable {
    case all = "AO0 · All thirteen pages, as today"
    case grouped = "AO1 · Six pages; related ones share a page (Types: domains, composite, range)"
    case split = "AO2 · Four tools of their own (Types, Text and Languages, Programming, Storage), 2 to 4 pages each"

    static let revision2: [LabTBarAdvanced] = [.split]

    var summary: String {
        switch self {
        case .all: "Too wide for any window once other tabs are open."
        case .grouped: "Fits, but a page now holds several lists behind a second control."
        case .split: "Every page keeps its own list; the Explorer's folder gains four rows instead of one."
        }
    }
}

/// With AO2, the thirteen pages become four tools; the Explorer's Advanced Objects folder opens each.
enum LabTBarSplitPart: String, CaseIterable {
    case types = "Types"
    case text = "Text and Languages"
    case programming = "Programming"
    case storage = "Storage"

    var pages: [String] {
        switch self {
        case .types: ["Domains", "Composite Types", "Range Types", "Casts"]
        case .text: ["Collations", "Text Search", "Languages"]
        case .programming: ["Aggregates", "Operators", "Rules", "Event Triggers"]
        case .storage: ["Tablespaces", "Foreign Data"]
        }
    }
}

/// The size of the window: what the tab strip gets is the window less the rail and the tree.
enum LabTBarWindow: String, CaseIterable {
    case small = "1280 pt · a 13-inch laptop"
    case medium = "1512 pt · a 14-inch laptop"
    case large = "1728 pt · a 16-inch laptop"

    var windowWidth: CGFloat {
        switch self {
        case .small: 1280
        case .medium: 1512
        case .large: 1728
        }
    }

    /// The strip's track: the window less the rail, the tree, the card gaps and the add button.
    var stripWidth: CGFloat { windowWidth - 300 }
}

/// Whose tabs are open.
enum LabTBarServers: String, CaseIterable {
    case one = "One server"
    case two = "Two servers"
}

/// The tool whose tab is open in the strip.
enum LabTBarTool: String, CaseIterable {
    case activity = "Activity Monitor · PostgreSQL (11 pages)"
    case advanced = "Advanced Objects · PostgreSQL (13 pages)"
    case security = "Database Security · MySQL (9 pages)"
    case maintenance = "Maintenance · SQL Server (5 pages)"
    case policy = "Policy Management (4 pages)"

    func title(_ advanced: LabTBarAdvanced, part: LabTBarSplitPart) -> String {
        self == .advanced && advanced == .split ? part.rawValue : title
    }

    var title: String {
        switch self {
        case .activity: "Activity Monitor"
        case .advanced: "Advanced Objects"
        case .security: "Database Security"
        case .maintenance: "Maintenance"
        case .policy: "Policy Management"
        }
    }

    var kindName: String {
        switch self {
        case .activity: "Activity Monitor"
        case .advanced: "Advanced Objects (PostgreSQL)"
        case .security: "Database Security"
        case .maintenance: "Maintenance"
        case .policy: "Policy Management"
        }
    }

    func pages(_ advanced: LabTBarAdvanced, part: LabTBarSplitPart = .types) -> [String] {
        switch self {
        case .activity:
            ["Sessions", "Locks", "Database", "Operations", "Queries", "Replication", "I/O Stats", "WAL", "BGWriter", "Prepared Txns", "Configuration"]
        case .advanced:
            advanced == .split ? part.pages
            : advanced == .all
                ? ["Foreign Data", "Event Triggers", "Domains", "Composite Types", "Range Types", "Collations", "Text Search", "Rules",
                   "Tablespaces", "Aggregates", "Operators", "Languages", "Casts"]
                : ["Foreign Data", "Triggers & Rules", "Types", "Text", "Tablespaces", "Functions"]
        case .security:
            ["Users", "Roles", "Privileges", "Advanced Objects", "Password Policies", "Data Masking", "Encryption", "Audit", "Firewall"]
        case .maintenance:
            ["Health", "Tables", "Indexes", "Backups", "Query Store"]
        case .policy:
            ["Policies", "Conditions", "Facets", "History"]
        }
    }
}
