import SwiftUI

/// Round 35.1 · Tab overview: the direction. Echo today (TabOverview/*, plan O1 to O3): "Open
/// Tabs" with a count and Collapse All / Expand All; each server in large bold with a tab-count
/// capsule; a tinted band per database; UPPERCASE kind headings (QUERIES 2, JOBS 1); cards with the
/// SQL on a blue gradient and status chips. The owner finds it hideous and wants many different
/// ways of looking at it. Accepted 2026-10-01: TO6, the palette, built as a scope of ⌘K; the page
/// is trimmed to it.
@MainActor
enum TabOverviewDirectionRound {
    static let spec = RoundSpec(
        controls: [
            .of("thumbnail", "Card picture", LabTOThumbnail.self, default: .snapshot),
        ],
        exhibits: [LabTODirection.palette].map { direction in
            RoundSpec.Exhibit(id: "\(direction)", title: direction.rawValue, summary: direction.summary,
                              isEchoToday: true, isWide: true, designWidth: 760, designHeight: 470) { values in
                LabTODirectionView(direction: direction, thumbnail: LabTOThumbnail(rawValue: values["thumbnail"]) ?? .snapshot)
            }
        },
        questions: [
            .init(id: "role", title: "What the overview is for",
                  question: "Which job should the overview do best?",
                  choices: [
                      .init(id: "find", name: "OR0 · Find one tab fast, among many"),
                      .init(id: "survey", name: "OR1 · See everything that's open and what state it's in"),
                      .init(id: "tidy", name: "OR2 · Tidy up: close, move and group tabs"),
                  ],
                  recommended: "survey",
                  why: "The tab strip and ⌘1–9 already find a tab you know; what nothing else gives you is all servers' tabs and their states (running, failed, never run) at once. Finding by typing still works in every direction through search (35.3)."),
            .init(id: "scope", title: "Which tabs",
                  question: "Should the overview show the tabs of every window and server, or only this window's?",
                  choices: [
                      .init(id: "window", name: "OS0 · This window's tabs (today)"),
                      .init(id: "all", name: "OS1 · Every window's tabs, this window's first"),
                  ],
                  recommended: "window",
                  why: "Tabs live in a window's strip; showing another window's tabs and then moving you there is surprising. Revisit when Echo has more than one window in daily use."),
        ],
        exhibitTopic: ("Which direction?", "Accepted: the palette (TO6), built into Echo as the ⌘K palette's tab scope with ⌫, ⌘D and ⌥⌫.", "\(LabTODirection.palette)",
                       "The owner's pick. It joins the ⌘K palette instead of taking a shortcut of its own, so search, actions and the tabs stay one place to learn."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "Snapshots of the whole tab.",
                  values: ["thumbnail": LabTOThumbnail.snapshot.rawValue], isRecommended: true),
        ]
    )
}
