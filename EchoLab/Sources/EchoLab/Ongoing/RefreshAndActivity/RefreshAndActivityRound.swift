import SwiftUI

/// Round 34 · Refresh and the activity signal. Echo today: RefreshToolbarButton sits in the
/// [Overview · Refresh · Bell · Inspector] capsule. Clicking it reloads the front tab (each tool tab's
/// view model; on a query tab the selected database's schema, which EchoSense and the tree use). Its
/// icon also mirrors the ActivityEngine for the server: a spinner while anything runs, then ✓ or ✗
/// (RefreshToolbarButton+Content). Running a query begins "Executing query"
/// (WorkspaceTabContainerView+Execution), so after a run both Run and Refresh show ✓.
@MainActor
enum RefreshAndActivityRound {
    enum Signal: String, CaseIterable {
        case today = "AS0 · Refresh mirrors every operation, query runs included (today)"
        case notQueries = "AS1 · Refresh mirrors every operation except query runs"
        case ownOnly = "AS2 · Refresh shows only its own reload; long operations report through the bell"
        case activity = "AS3 · An Activity button replaces Refresh: a spinner while anything runs, a list on click"

        var summary: String {
            switch self {
            case .today: "The bug you saw: Run's ✓ and Refresh's ✓ for the same query."
            case .notQueries: "The smallest fix: Run reports queries, Refresh everything else (backups, DDL, schema loads)."
            case .ownOnly: "Each control says only what it did. A backup shows a spinner on the bell and a notification when it ends."
            case .activity: "One place for everything running on the server, with cancel; refresh moves into the tabs (see below)."
            }
        }
    }

    enum Place: String, CaseIterable {
        case toolbar = "RL0 · In the toolbar, for every tab (today)"
        case toolbarWhenUseful = "RL1 · In the toolbar only while the front tab can reload"
        case inTabs = "RL2 · In each tool tab's header, and ⌘R; none in the toolbar"

        var summary: String {
            switch self {
            case .toolbar: "Always there; on a query tab it reloads the schema."
            case .toolbarWhenUseful: "Hidden on query tabs; appears for Activity Monitor, Agent Jobs, Error Log and the like."
            case .inTabs: "Beside the data it reloads, like Activity Monitor's own refresh, following round 37's tab header."
            }
        }
    }

    struct Look {
        var signal: Signal, place: Place
        static let today = Look(signal: .today, place: .toolbar)
        @MainActor static func from(_ v: RoundValues) -> Look {
            Look(signal: .init(rawValue: v["signal"]) ?? .ownOnly, place: .init(rawValue: v["place"]) ?? .inTabs)
        }
    }

    static let spec = RoundSpec(
        controls: [
            .of("signal", "Activity", Signal.self, default: .ownOnly,
                question: "Press Run a query, then Start a backup, in each exhibit. Where should finished work be signalled?",
                recommend: .ownOnly,
                why: "A control should only tell you about itself: Run already shows the query's ✓, and a checkmark on Refresh for work you didn't start there reads as a refresh you didn't ask for. Long operations already post notifications; a spinner on the bell while one runs finishes the job. AS3 is right if you often run several long operations at once.",
                summary: \.summary),
            .of("place", "Refresh", Place.self, default: .inTabs,
                question: "Look at where Refresh is in each exhibit, on a query tab and on Activity Monitor.",
                recommend: .inTabs,
                why: "Refresh reloads one tab's data, so it belongs on that tab, where the data is; on a query tab the schema reload already happens on its own and from the tree. That frees a toolbar slot and ends the question of what the toolbar button does.",
                summary: \.summary),
        ],
        actions: [
            .init(id: "run", title: "Run a query", symbol: "play.fill") { $0["pulse"] = "query|\(UUID().uuidString)" },
            .init(id: "backup", title: "Start a backup", symbol: "externaldrive.badge.timemachine") { $0["pulse"] = "backup|\(UUID().uuidString)" },
            .init(id: "reload", title: "Press Refresh", symbol: "arrow.clockwise") { $0["pulse"] = "refresh|\(UUID().uuidString)" },
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Refresh shows every operation's result, so a query run puts ✓ on both.",
                  isEchoToday: true, designWidth: 640, designHeight: 300) { values in
                LabRFScene(look: .today, values: values)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls.",
                  designWidth: 640, designHeight: 300) { values in
                LabRFScene(look: Look.from(values), values: values)
            },
        ],
        questions: [
            .init(id: "queryTab", title: "Refresh on a query tab",
                  question: "If Refresh stays where a query tab can reach it, what should it do there?",
                  choices: [
                      .init(id: "schema", name: "QR0 · Reload the database's schema (today)"),
                      .init(id: "nothing", name: "QR1 · Nothing; the schema reloads from the tree's menu and after DDL"),
                      .init(id: "rerun", name: "QR2 · Run the last query again"),
                  ],
                  recommended: "nothing",
                  why: "Echo reloads the schema after DDL it runs, and the tree's server menu has Refresh for changes made elsewhere; re-running a query from a button called Refresh would surprise anyone whose last query was an UPDATE."),
            .init(id: "shortcut", title: "⌘R",
                  question: "What should ⌘R do?",
                  choices: [
                      .init(id: "tab", name: "KR0 · Reload the front tool tab"),
                      .init(id: "none", name: "KR1 · Nothing (keep it free)"),
                  ],
                  recommended: "tab",
                  why: "⌘R is reload in Safari, Xcode's Instruments and Activity Monitor, so it's where the hand goes."),
        ],
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "Each control signals itself; Refresh lives in the tool tabs.",
                  values: ["signal": Signal.ownOnly.rawValue, "place": Place.inTabs.rawValue], isRecommended: true),
            .init(id: "smallest", name: "Smallest fix", summary: "Keep Refresh; stop mirroring query runs.",
                  values: ["signal": Signal.notQueries.rawValue, "place": Place.toolbar.rawValue]),
            .init(id: "activity", name: "Activity centre", values: ["signal": Signal.activity.rawValue, "place": Place.inTabs.rawValue]),
        ]
    )
}
