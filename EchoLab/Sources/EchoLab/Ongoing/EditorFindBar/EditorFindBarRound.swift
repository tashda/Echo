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
            .of("findBar", "Where and how", LabQEFindBarPlace.self, default: .safari,
                question: "Look at the Places gallery (rev 2: seven immersive glass bars, FB4 to FB10), then press through Finding and Replacing in the Proposal. Which find bar?",
                recommend: .safari,
                why: "You liked the glass strip and asked for an immersive glass capsule. FB5 is how macOS 26 itself does it (Safari's bar): the search on glass, with its buttons as glass circles that melt into it, so it reads as one control without a white box. It floats over the code's top edge without pushing it. FB4 (one capsule) is the close runner-up and narrower; FB6 keeps your strip but spans the whole card. My first recommendation was the system's bar (FB0): taking a glass bar means rebuilding Replace, ⌘E and ⌘G ourselves.",
                summary: \.summary, newChoices: (2, LabQEFindBarPlace.addedInRev2)),
            .of("replaceStyle", "Replace", LabQEReplaceStyle.self, default: .preview,
                question: "Set The editor shows to Replacing “orders” and try each. How should Replace work?",
                recommend: .preview,
                why: "Replacing in a SQL script can change a table name you didn't mean to touch; showing each replacement in place before anything changes makes Replace All safe to press. The chevron (RP1) is the most compact; a separate capsule spreads the bar too wide over the code.",
                summary: \.summary, addedIn: 2),
            .of("findScope", "What it searches", LabQEFindScope.self, default: .selectionAuto,
                question: "How should find limit itself to the selected text, if at all?",
                recommend: .selectionAuto,
                why: "Selecting a few lines and pressing ⌘F almost always means “find in these”, and selecting one word means “find this word” (your SE1), so the selection tells Echo what you want without a button. The button (SS2) is the safe runner-up; Script / Statement / Selection is powerful but one more control on every search.",
                summary: \.summary, addedIn: 2),
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
            LabQERound.gallery("Places", "Every find bar, on the proposal (rev 2: FB4 to FB10, immersive glass).", LabQEFindBarPlace.self, \.findBar,
                               scene: .find, cellHeight: 170),
            LabQERound.gallery("Replace", "Every way to replace, on the proposal, replacing “orders” with “orders_2026”.", LabQEReplaceStyle.self, \.replaceStyle,
                               scene: .replace, id: "replaceGallery", addedIn: 2, cellHeight: 190),
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
                       "An immersive glass bar that floats over the code, previews every replacement, and searches the selection when you select lines."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "Safari-style glass, options in the menu, “2 found”, replacements previewed, the selection searched when it spans lines.",
                  values: ["findBar": LabQEFindBarPlace.safari.rawValue, "findOptions": LabQEFindOptions.menu.rawValue, "findCount": LabQEFindCount.found.rawValue,
                           "replaceStyle": LabQEReplaceStyle.preview.rawValue, "findScope": LabQEFindScope.selectionAuto.rawValue],
                  isRecommended: true),
            .init(id: "systemBar", name: "The system's bar", summary: "Today's bar, nothing rebuilt.",
                  values: ["findBar": LabQEFindBarPlace.native.rawValue, "findOptions": LabQEFindOptions.menu.rawValue, "findCount": LabQEFindCount.found.rawValue,
                           "replaceStyle": LabQEReplaceStyle.secondRow.rawValue, "findScope": LabQEFindScope.editor.rawValue]),
            .init(id: "ssms", name: "Like SSMS and VS Code", summary: "A floating panel at the top right, option buttons, “1 of 2”.",
                  values: ["findBar": LabQEFindBarPlace.floating.rawValue, "findOptions": LabQEFindOptions.toggles.rawValue, "findCount": LabQEFindCount.position.rawValue]),
        ]
    )
}
