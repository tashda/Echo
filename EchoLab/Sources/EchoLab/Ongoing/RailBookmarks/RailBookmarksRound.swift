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
            .of("list", "List", ListLook.self, default: .preview,
                question: "Compare the lists. Which helps you find and recognise a bookmark?",
                recommend: .preview,
                why: "One list for every server, folders as in Finder, search at the top; the selected bookmark shows its SQL so you know what it does before opening it. Cards for every bookmark take three times the height."),
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
                LabRTScene(selected: 0) { LabRBList(look: ListLook(rawValue: values["list"]) ?? .preview, folders: (Holds(rawValue: values["holds"]) ?? .folders) == .folders) }
            },
            .init(id: "saving", title: "Saving", summary: "⌘D in a query tab, with BS2's popover.", isWide: true, designWidth: 760, designHeight: 300) { values in
                LabRBSaving(save: Save(rawValue: values["save"]) ?? .popover)
            },
        ],
        questions: [
            .init(id: "parameters", title: "Bookmarks with blanks",
                  question: "A bookmark like 'Reset OH checkpoint' has a date in it. Should bookmarks be able to ask for values when opened?",
                  choices: [.init(id: "later", name: "BP0 · Not now; snippets have placeholders (39.3)"), .init(id: "yes", name: "BP1 · Yes: ${date} asks when the bookmark opens")],
                  recommended: "later",
                  why: "Placeholders belong to snippets, which are made for it; a bookmark is a query as you ran it."),
        ],
        presets: [.init(id: "recommended", name: "My recommendation", values: ["save": Save.popover.rawValue, "holds": Holds.folders.rawValue, "list": ListLook.preview.rawValue, "open": Open.insert.rawValue], isRecommended: true)]
    )
}

/// The proposed list: all servers, folders, search, selected bookmark's SQL.
private struct LabRBList: View {
    let look: RailBookmarksRound.ListLook
    let folders: Bool
    @State private var selected = "b2"

    var body: some View {
        if look == .today {
            LabRTBookmarksToday()
        } else {
            LabRTColumn(title: "Bookmarks", subtitle: "\(LabRTBookmark.samples.count) saved", trailing: AnyView(Image(systemName: "folder.badge.plus").foregroundStyle(ColorTokens.Text.secondary))) {
                LabRTSearch(prompt: "Search bookmarks")
                ScrollView {
                    VStack(alignment: .leading, spacing: SpacingTokens.none) {
                        ForEach(groups, id: \.0) { title, items in
                            LabRTHeading(title: title, count: items.count)
                            ForEach(items) { bookmark in
                                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                                    LabRTRow(symbol: "bookmark", title: bookmark.title, detail: "\(bookmark.server) · \(bookmark.database)")
                                    if look == .preview, bookmark.id == selected {
                                        Text(bookmark.sql).font(TypographyTokens.detail.monospaced()).foregroundStyle(ColorTokens.Text.secondary)
                                            .padding(SpacingTokens.xs).frame(maxWidth: .infinity, alignment: .leading)
                                            .background(ColorTokens.Workspace.groupFill, in: .rect(cornerRadius: SpacingTokens.xs))
                                            .padding(.horizontal, SpacingTokens.sm).padding(.bottom, SpacingTokens.xxs)
                                        if let note = bookmark.note {
                                            Label(note, systemImage: "note.text").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                                                .padding(.horizontal, SpacingTokens.sm).padding(.bottom, SpacingTokens.xs)
                                        }
                                    }
                                }
                                .background(bookmark.id == selected ? ColorTokens.Sidebar.selectedFill : .clear, in: .rect(cornerRadius: SpacingTokens.xs))
                                .padding(.horizontal, SpacingTokens.xxs)
                                .onTapGesture { selected = bookmark.id }
                            }
                        }
                    }
                }
            }
        }
    }

    private var groups: [(String, [LabRTBookmark])] {
        folders ? ["AML", "Bags", "DBA", "Unfiled"].map { f in (f, LabRTBookmark.samples.filter { $0.folder == f }) }
                : LabRTBookmark.servers.map { s in (s, LabRTBookmark.samples.filter { $0.server == s }) }
    }
}

extension LabRTBookmark {
    static let servers = ["dkloosql10-p", "postgres18"]
}

/// A query tab with the ☆ on the tab and the save popover open.
private struct LabRBSaving: View {
    let save: RailBookmarksRound.Save

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack(spacing: SpacingTokens.none) {
                HStack(spacing: SpacingTokens.xs) {
                    Label("Query 1", systemImage: "tablecells").font(TypographyTokens.detail)
                    if save != .today { Image(systemName: "star").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary) }
                }
                .frame(maxWidth: .infinity).frame(height: SpacingTokens.lg)
                .background(Capsule().fill(ColorTokens.Workspace.card).shadow(ShadowTokens.railSelection))
                Label("Query 2", systemImage: "tablecells").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary).frame(maxWidth: .infinity)
            }
            .padding(SpacingTokens.xxxs).background(ColorTokens.Sidebar.hoverFill, in: Capsule())
            ZStack(alignment: .topLeading) {
                LabWKEditor().workspaceCard()
                if save == .popover {
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        Text("Add to Bookmarks").font(TypographyTokens.headline)
                        LabeledContent("Name") { Text("Last checkpoints").padding(.horizontal, SpacingTokens.xxs2).padding(.vertical, SpacingTokens.xxxs).background(ColorTokens.Workspace.groupFill, in: .rect(cornerRadius: SpacingTokens.xxs)) }
                        LabeledContent("Folder") { Text("AML ⌄") }
                        LabeledContent("Note") { Text("Optional").foregroundStyle(ColorTokens.Text.tertiary) }
                        HStack { Spacer(); Button("Cancel") {}; Button("Add") {}.buttonStyle(.borderedProminent) }
                    }
                    .font(TypographyTokens.standard)
                    .padding(SpacingTokens.md).frame(width: 300)
                    .glassEffect(.regular, in: .rect(cornerRadius: SpacingTokens.md))
                    .padding(.leading, SpacingTokens.lg).padding(.top, SpacingTokens.xxs)
                }
            }
        }
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ColorTokens.Workspace.canvas)
    }
}
