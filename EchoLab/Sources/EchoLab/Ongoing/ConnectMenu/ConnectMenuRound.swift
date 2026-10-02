import SwiftUI

/// Round 52 · The + button: connecting to a server. Echo today: the + at the foot of the trail's
/// glass pill opens a system menu below it (open sessions, saved connections with folders as
/// submenus, Manage Connections, Quick Connect). The owner finds it "too little", a poor way to
/// show saved connections, and out of place under a liquid-glass pill; they suggest opening to the
/// right with the + animating into a chevron. This round varies where the list opens (PR), what the
/// + does (MP), how connections are listed (CT), where the actions live (FT) and how many there are.
@MainActor
enum ConnectMenuRound {
    private static let windowWidth = LayoutTokens.Workspace.treeIdealWidth + SpacingTokens.xxxl * 3.6

    static let spec = RoundSpec(
        controls: [
            .of("presentation", "Where it opens", LabCMPresentation.self, default: .panel,
                question: "Press the + in the Proposal with each presentation, at Five and at Forty connections. Where should the list of connections open?",
                recommend: .panel,
                why: "You said the menu feels off under the glass and wanted it to the right: the panel does that and stays level with the +, so the thing you pressed and what it opened are one gesture. The drawer and the palette are better for forty connections but are further from the + and cover more of the tree; the widened trail (PR4) is the most elegant and the one I would try next if the panel feels detached.",
                summary: \.summary),
            .of("morph", "The +", LabCMMorph.self, default: .chevronBack,
                question: "Open and close the list with each. What should the + do while it is open?",
                recommend: .chevronBack,
                why: "It tells you what pressing again does, which the + alone does not: ‹ points back at the trail and reads as \"close\", where the × (MP1) reads as \"delete\" next to server marks. The chevron pointing at the list (MP3) says \"open\" when it is already open. The lift (MP4) is the most beautiful and the one most likely to look wrong at Corners 10, so look at it at 26.",
                summary: \.summary),
            .of("content", "The list", LabCMContent.self, default: .search,
                question: "Compare the lists in Every list, then in the Proposal. How should connections be shown?",
                recommend: .search,
                why: "With twelve connections (forty for some) the question is finding one: search first, grouped by what you already named (folders), with the host and database under each name so mssql25 and mssql25 (Copy) are told apart. Recent (CT2) is better if you reconnect to the same five; the engine grouping (CT4) hides your folders, which you made on purpose.",
                summary: \.summary),
            .of("footer", "Actions", LabCMFooter.self, default: .bar,
                question: "Where should Manage Connections, Quick Connect and New Connection be?",
                recommend: .bar,
                why: "A footer bar stays in view while the list scrolls, which a menu's last rows do not once there are forty connections. Today's rows (FT0) are the right choice only with the menu; FT2 makes New primary, which is a bet that you connect to new servers more often than I think you do.",
                summary: \.summary),
            .of("count", "Connections", LabCMCount.self, default: .some),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today",
                  summary: "The system menu under the +. Press it.",
                  isEchoToday: true, designWidth: windowWidth, designHeight: 520) { _ in
                LabCMWindow(look: .today)
            },
            .init(id: "proposal", title: "Proposal",
                  summary: "Built from the controls. Press the + to open, again (or Escape) to close.",
                  designWidth: windowWidth, designHeight: 520) { values in
                LabCMWindow(look: LabCMLook(values))
            },
            .init(id: "lists", title: "Every list",
                  summary: "The five contents side by side in a panel, with the chosen footer and number of connections. Hover, search and fold.",
                  designWidth: 700, designHeight: 620) { values in
                LabCMGallery(look: LabCMLook(values))
            },
        ],
        questions: [
            .init(id: "shortcut", title: "Keyboard",
                  question: "Should the list have a shortcut and type-to-connect?",
                  choices: [
                      .init(id: "none", name: "KB0 · No: the mouse opens it", summary: nil),
                      .init(id: "open", name: "KB1 · A shortcut opens it with the search field focused; Return connects, Escape closes", summary: nil),
                  ],
                  recommended: "open",
                  why: "Connecting is something you do many times a day on a laptop: ⌘⇧O (or another shortcut you choose) to type \"tip\" and press Return is faster than reaching for the + at any size of list."),
            .init(id: "menuStays", title: "The menu bar",
                  question: "Keep the system menu anywhere once the list replaces it under the +?",
                  choices: [
                      .init(id: "none", name: "SM0 · No: the list replaces it everywhere", summary: nil),
                      .init(id: "file", name: "SM1 · Yes: File › Connect To keeps the menu for the menu bar", summary: nil),
                  ],
                  recommended: "file",
                  why: "The menu bar needs a menu for accessibility and for people who navigate by keyboard; it costs nothing to keep and is not what the owner is judging here."),
        ],
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "A glass panel beside the +, which turns to ‹, a searchable list and a footer bar.",
                  values: ["presentation": LabCMPresentation.panel.rawValue, "morph": LabCMMorph.chevronBack.rawValue,
                           "content": LabCMContent.search.rawValue, "footer": LabCMFooter.bar.rawValue],
                  isRecommended: true),
            .init(id: "trail", name: "The trail opens", summary: "The pill widens into the list; the + is a chevron.",
                  values: ["presentation": LabCMPresentation.rail.rawValue, "morph": LabCMMorph.chevronBack.rawValue,
                           "content": LabCMContent.recent.rawValue, "footer": LabCMFooter.split.rawValue]),
            .init(id: "lift", name: "Liquid", summary: "The + lifts out and grows into the panel.",
                  values: ["presentation": LabCMPresentation.panel.rawValue, "morph": LabCMMorph.lift.rawValue,
                           "content": LabCMContent.tiles.rawValue, "footer": LabCMFooter.bar.rawValue]),
            .init(id: "palette", name: "Palette", summary: "A Spotlight-style palette with search first.",
                  values: ["presentation": LabCMPresentation.palette.rawValue, "morph": LabCMMorph.none.rawValue,
                           "content": LabCMContent.search.rawValue, "footer": LabCMFooter.split.rawValue]),
        ]
    )
}
