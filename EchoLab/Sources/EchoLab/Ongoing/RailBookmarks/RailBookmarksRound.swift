import SwiftUI

/// Round 39.2 · Rail tools: Bookmarks. Echo today: a bookmark (Bookmark.swift) holds the SQL, the
/// server, the database, an optional title and where it came from. You save one with Add to
/// Bookmarks in a tab's right-click menu or the editor's (with a selection). The list shows one
/// server at a time (a server picker), grouped by database in UPPERCASE, a card per bookmark; opening
/// one opens a new query tab with its SQL.
@MainActor
enum RailBookmarksRound {
    enum Save: String, CaseIterable {
        case today = "BS0 · Right-click a tab or a selection › Add to Bookmarks (today)"
        case shortcut = "BS1 · BS0, plus ⌘D and a ☆ on the tab when you hover it"
        case popover = "BS2 · BS1, and saving opens a small popover: name, folder, note"
    }

    enum Holds: String, CaseIterable {
        case today = "BH0 · SQL, server, database, title (today)"
        case folders = "BH1 · BH0, plus a folder and a note"
    }

    enum ListLook: String, CaseIterable {
        case today = "BL0 · One server at a time, database groups, a card each (today)"
        case rows = "BL1 · All servers, folders, quiet two-line rows, search"
        case preview = "BL2 · BL1 with the SQL shown under the selected bookmark"
        case inline = "BL3 · Native folder list, SQL beneath the selected row"
        case detail = "BL4 · Native folder list, SQL in a fixed detail pane"
    }

    enum Open: String, CaseIterable {
        case newTab = "BO0 · Click opens a new tab (today)"
        case insert = "BO1 · Click opens a new tab; ⌥-click or drag inserts at the caret"
    }

    static let spec = RoundSpec(
        controls: [
            .of("save", "Saving", Save.self, default: .popover,
                question: "How should a query become a bookmark?",
                recommend: .popover,
                why: "⌘D is bookmark on the Mac (Safari, Finder's Favourites); the popover asks the one thing you'll want later, a name, while it's on your mind, with the first line of SQL already filled in so Return saves at once."),
            .of("holds", "A bookmark holds", Holds.self, default: .folders,
                question: "What should a bookmark keep besides its SQL?",
                recommend: .folders,
                why: "A list of more than 15 bookmarks needs folders; a note keeps 'only run after the OH import failed' with the UPDATE that needs it."),
            .of("list", "List", ListLook.self, default: .inline,
                question: "Compare the lists. Which helps you find and recognise a bookmark?",
                recommend: .inline,
                why: "You chose SQL beneath the selected bookmark. BL3 gives it a native selection, quieter folder headings and readable SQL with no card inside a selected card. BL4 keeps the list stable but separates the preview from its row.",
                addedIn: 2, newChoices: (2, [.inline, .detail])),
            .of("open", "Opening", Open.self, default: .insert,
                question: "What should clicking a bookmark do?",
                recommend: .insert,
                why: "A new tab is right most of the time; adding a snippet of saved SQL into the query you're writing is the other common case, and drag is how you'd try it first."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "As built.", isEchoToday: true, isWide: true, designWidth: 760, designHeight: 460) { _ in
                LabRTScene(selected: 0) { LabRTBookmarksToday() }
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls.", isWide: true, designWidth: 760, designHeight: 460) { values in
                let look = ListLook(rawValue: values["list"]) ?? .inline
                if look == .inline || look == .detail { LabRBInspectorScene(look: look) }
                else { LabRTScene(selected: 0) { LabRBList(look: look, folders: (Holds(rawValue: values["holds"]) ?? .folders) == .folders) } }
            },
            .init(id: "saving", title: "Saving", summary: "⌘D in a query tab, with BS2's popover.", isWide: true, designWidth: 760, designHeight: 300) { values in
                LabRBSaving(save: Save(rawValue: values["save"]) ?? .popover)
            },
            .init(id: "inline", title: "BL3 · Inline preview", summary: "New: native folder list; SQL and note beneath the selected row, in the inspector column.", isWide: true, addedIn: 2, designWidth: 860, designHeight: 520) { _ in
                LabRBInspectorScene(look: .inline)
            },
            .init(id: "detail", title: "BL4 · Fixed preview", summary: "New: the list keeps its height; selected SQL and note have a separate pane below.", isWide: true, addedIn: 2, designWidth: 860, designHeight: 520) { _ in
                LabRBInspectorScene(look: .detail)
            },
        ],
        questions: [
            .init(id: "parameters", title: "Bookmarks with blanks",
                  question: "A bookmark like 'Reset OH checkpoint' has a date in it. Should bookmarks be able to ask for values when opened?",
                  choices: [.init(id: "later", name: "BP0 · Not now; snippets have placeholders (39.3)"), .init(id: "yes", name: "BP1 · Yes: ${date} asks when the bookmark opens")],
                  recommended: "later",
                  why: "Placeholders belong to snippets, which are made for it; a bookmark is a query as you ran it."),
        ],
        presets: [.init(id: "recommended", name: "My recommendation", values: ["save": Save.popover.rawValue, "holds": Holds.folders.rawValue, "list": ListLook.inline.rawValue, "open": Open.insert.rawValue], isRecommended: true)]
    )
}
