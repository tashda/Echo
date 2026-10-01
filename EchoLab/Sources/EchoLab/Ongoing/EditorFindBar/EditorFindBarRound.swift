import SwiftUI

/// Round 28.12 · Editor: the find bar (asked in the owner's notes on 28.5). Echo today
/// (SQLTextView: usesFindBar, isIncrementalSearchingEnabled): NSTextView's find bar above the
/// text, the card's full width, pushing the code down while open; Ignore Case and Contains /
/// Starts With / Full Word in the magnifier's menu, no regular expressions; “2 found”; Replace
/// opens a second row. The marks on the matches themselves are page 28.5.
@MainActor
enum EditorFindBarRound {
    static let spec = RoundSpec(
        controls: [
            .of("findBar", "Where", LabQEFindBarPlace.self, default: .native,
                question: "Look at the gallery, then press through Finding and Replacing in the Proposal. Where should the find bar be?",
                recommend: .native,
                why: "It is the Mac's own find: Replace, ⌘E (use selection), ⌘G and the shared find text with other apps, VoiceOver, and the dimming in 28.5 all come with it, and it already sits inside the card. The floating panel (FB1) is the best of the drawn ones, as SSMS and VS Code users expect, but it covers the code's top-right corner, and every feature above would be ours to rebuild.",
                summary: \.summary),
            .of("findOptions", "Options", LabQEFindOptions.self, default: .menu,
                question: "How should Ignore Case, Whole Word and (with a bar of Echo's own) regular expressions be reached?",
                recommend: .menu,
                why: "With the system bar they live in the magnifier's menu and can't move. If you choose a bar of Echo's own, take the buttons (O1): Aa, ab and .* are what SSMS and VS Code users look for.",
                summary: \.summary),
            .of("findCount", "Match count", LabQEFindCount.self, default: .found,
                question: "Should the count say how many matches there are, or where you are among them?",
                recommend: .found,
                why: "“2 found” is what the system bar shows and can't change. “1 of 2” is better while stepping with ⌘G; take it with a bar of Echo's own."),
            LabQERound.sceneControl(default: .find),
            LabQERound.baseControl,
        ],
        exhibits: [
            LabQERound.today("The system's find bar above the text, on “orders”; switch The editor shows to Replacing for its second row.", scene: .find),
            LabQERound.proposal("Built from the controls; the matches look as page 28.5 recommends.", scene: .find),
            LabQERound.gallery("Places", "Every place for the find bar, on the proposal.", LabQEFindBarPlace.self, \.findBar, scene: .find),
        ],
        questions: [
            .init(id: "regex", title: "Regular expressions",
                  question: "Should find support regular expressions? The system's bar can't; it needs a bar of Echo's own.",
                  choices: [
                      .init(id: "no", name: "RX0 · No (today)"),
                      .init(id: "yes", name: "RX1 · Yes, with a .* button"),
                  ],
                  recommended: "no",
                  why: "In SQL scripts you mostly search names and keywords, which Whole Word and Ignore Case cover; regular expressions alone don't justify replacing the Mac's find. Say Yes if you often rewrite many similar lines: then FB1 with O1 is the package."),
            .init(id: "scope", title: "What it searches",
                  question: "With the editor focused, ⌘F finds in the script. Should it also find in the results grid?",
                  choices: [
                      .init(id: "editor", name: "SC0 · The script only; the grid has its own ⌘F when it has the keyboard"),
                      .init(id: "both", name: "SC1 · Script and results together"),
                  ],
                  recommended: "editor",
                  why: "⌘F acts on what has the keyboard everywhere on the Mac; mixing script and rows in one count makes ⌘G jump between cards."),
            .init(id: "selection", title: "Starting from a selection",
                  question: "You select a table name and press ⌘F. What should the field hold?",
                  choices: [
                      .init(id: "native", name: "SE0 · The last search; ⌘E puts the selection in (the Mac's way, today)"),
                      .init(id: "fill", name: "SE1 · The selection, every time"),
                  ],
                  recommended: "fill",
                  why: "Selecting a word and pressing ⌘F to find its other uses is how almost everyone searches code; SSMS, Xcode and VS Code all do it. NSTextView can take the selection as the find string before showing the bar, so the native bar keeps everything else."),
        ],
        exhibitTopic: ("Which find bar?", "Find and replace in both. Is the proposal better than Echo today?", "proposal",
                       "Keep the Mac's find bar, and let ⌘F start from the selection."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "The system's bar, options in its menu, “2 found”.",
                  values: ["findBar": LabQEFindBarPlace.native.rawValue, "findOptions": LabQEFindOptions.menu.rawValue, "findCount": LabQEFindCount.found.rawValue],
                  isRecommended: true),
            .init(id: "ssms", name: "Like SSMS and VS Code", summary: "A floating panel at the top right, option buttons, “1 of 2”.",
                  values: ["findBar": LabQEFindBarPlace.floating.rawValue, "findOptions": LabQEFindOptions.toggles.rawValue, "findCount": LabQEFindCount.position.rawValue]),
        ]
    )
}
