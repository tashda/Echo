import SwiftUI

/// Round 38 · Tree rows that open a tab. Echo today: the SQL Server blueprint
/// (ExplorerBlueprint+SQLServer) puts `Tool(.jobQueue)` ("Agent Jobs Overview") first in Agent Jobs and
/// a column of tools in Management; Security has only Logins, Server Roles and Credentials, and
/// "Open Security Management" is only in the right-click menu of the server's and each database's
/// Security (ObjectBrowserSidebarView+ServerMenus, +DatabaseMenus). Tool rows look like any row: a
/// tinted symbol and a title, nothing to say a click opens a tab (Database Mail opens a sheet).
///
/// Accepted 2026-10-01: SN1, OT1 drawn without its square (the owner's note), MS0 (the owner's pick
/// over hover), DB0, SH0. Built into Echo as TREE-6.3.
@MainActor
enum TreeToolRowsRound {
    enum Name: String, CaseIterable {
        case management = "SN0 · Security Management (the menu's words)"
        case overview = "SN1 · Security Overview, like Agent Jobs Overview"
    }

    enum Mark: String, CaseIterable {
        case none = "OT0 · None (today)"
        case arrow = "OT1 · ↗ in a square at the right"
        case window = "OT2 · A small window symbol at the right"
        case tile = "OT3 · The row's symbol on a tinted tile, like the tool's tab header"

        var summary: String {
            switch self {
            case .none: "A tool row is told apart only by its title."
            case .arrow: "arrow.up.right.square: 'this goes somewhere else', as in Finder's and System Settings' links."
            case .window: "macwindow: 'this opens a view'; a sheet gets the same symbol."
            case .tile: "No mark at the right; the row's icon sits on the same tinted tile as the tool's header, so the row looks like the tab it opens."
            }
        }
    }

    enum MarkShows: String, CaseIterable {
        case always = "MS0 · Always"
        case hover = "MS1 · On hover and selection, like the counts used to"
    }

    struct Look {
        var name: Name, mark: Mark, shows: MarkShows, hasRow: Bool
        static let today = Look(name: .management, mark: .none, shows: .always, hasRow: false)
    }

    static let spec = RoundSpec(
        controls: [
            .of("name", "Row", Name.self, default: .overview,
                question: "Look at the new first row under Security. What should it be called?",
                recommend: .overview,
                why: "It sits exactly where Agent Jobs Overview sits in its section and does the same thing (opens the section as a tab), so the same word teaches one rule. The tab's own title stays Security."),
            .of("mark", "Opens a tab", Mark.self, default: .arrow,
                question: "Compare the marks on the rows that open a tab (Security Overview, Agent Jobs Overview and Management's tools).",
                recommend: .arrow,
                why: "The arrow is the system's 'goes elsewhere' mark and says it at the place you click. The window symbol reads as 'new window', which a tab isn't; the tile is lovely but changes the S4 Quiet rows you chose.",
                summary: \.summary),
            .of("shows", "When", MarkShows.self, default: .always,
                question: "Should the mark always show, or only when you point at the row?",
                recommend: .hover,
                why: "Management is a column of ten tools: ten arrows down the right edge are noise; on hover the mark answers 'what happens if I click' at the moment you ask."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "No Security row; tool rows look like folders and items.",
                  isEchoToday: true, designWidth: 320, designHeight: 560) { _ in
                LabTRCard(look: .today)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls. Hover the rows.",
                  designWidth: 320, designHeight: 560) { values in
                LabTRCard(look: Look(name: Name(rawValue: values["name"]) ?? .overview, mark: Mark(rawValue: values["mark"]) ?? .arrow,
                                     shows: MarkShows(rawValue: values["shows"]) ?? .hover, hasRow: true))
            },
        ],
        questions: [
            .init(id: "database", title: "In a database",
                  question: "Each database's Security folder has the same menu item. Should it get the row too?",
                  choices: [.init(id: "both", name: "DB0 · Yes: first row in every Security, server and database"), .init(id: "server", name: "DB1 · Only the server's")],
                  recommended: "both",
                  why: "Same folder name, same row: anything else makes you remember which Security has it."),
            .init(id: "sheet", title: "Rows that open a sheet",
                  question: "Database Mail opens a sheet, not a tab. Does it get the mark?",
                  choices: [.init(id: "same", name: "SH0 · The same mark: it goes somewhere else"), .init(id: "none", name: "SH1 · No mark until it opens a window or tab")],
                  recommended: "same",
                  why: "The mark answers 'will this expand or take me somewhere'; a sheet is somewhere. Database Mail is planned to move to a window anyway."),
        ],
        presets: [
            .init(id: "recommended", name: "My recommendation", values: ["name": Name.overview.rawValue, "mark": Mark.arrow.rawValue, "shows": MarkShows.hover.rawValue],
                  isRecommended: true),
        ]
    )
}

/// The server card showing Security, Agent Jobs and Management sections.
private struct LabTRCard: View {
    let look: TreeToolRowsRound.Look

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            LabSHHeader(server: .production, look: .today, section: "Security")
            LabSHDock(current: 1).padding(.vertical, SpacingTokens.xxs2)
            heading("Security")
            if look.hasRow { LabTRRow(title: look.name == .overview ? "Security Overview" : "Security Management", symbol: "lock.shield", tint: Color(nsColor: .systemPurple), isTool: true, look: look) }
            LabTRRow(title: "Logins", symbol: "person.2", tint: Color(nsColor: .systemPurple), trailing: "41", look: look)
            LabTRRow(title: "Server Roles", symbol: "person.3", tint: Color(nsColor: .systemPurple), trailing: "9", look: look)
            LabTRRow(title: "Credentials", symbol: "key", tint: Color(nsColor: .systemPurple), trailing: "2", look: look)
            heading("Agent Jobs")
            LabTRRow(title: "Agent Jobs Overview", symbol: "list.bullet.rectangle", tint: ColorTokens.accent, isTool: true, look: look)
            LabTRRow(title: "sp_purge_jobhistory", symbol: "clock", tint: ColorTokens.Text.secondary, trailing: "1", look: look)
            LabTRRow(title: "CommandLog Cleanup", symbol: "clock", tint: ColorTokens.Text.secondary, trailing: "1", look: look)
            heading("Management")
            ForEach([("Extended Events", "list.bullet.rectangle", Color(nsColor: .systemPurple)), ("Database Mail", "envelope", Color(nsColor: .systemIndigo)),
                     ("SQL Profiler", "chart.xyaxis.line", ColorTokens.Status.info), ("Resource Governor", "slider.horizontal.3", Color(nsColor: .systemTeal)),
                     ("Tuning Advisor", "wand.and.stars", ColorTokens.Status.warning), ("Policy Management", "checkmark.shield", ColorTokens.Status.success)], id: \.0) { tool in
                LabTRRow(title: tool.0, symbol: tool.1, tint: tool.2, isTool: true, look: look)
            }
            Spacer(minLength: 0)
        }
        .workspaceCard()
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ColorTokens.Workspace.canvas)
    }

    private func heading(_ title: String) -> some View {
        Text(title).font(SidebarRowConstants.sectionHeadingFont).foregroundStyle(ColorTokens.Text.secondary)
            .padding(.leading, SpacingTokens.sm).padding(.top, SpacingTokens.xs).frame(height: SpacingTokens.lg, alignment: .bottom)
    }
}

/// A row, with the opens-a-tab mark when it is a tool.
private struct LabTRRow: View {
    let title: String
    let symbol: String
    let tint: Color
    var trailing: String?
    var isTool = false
    let look: TreeToolRowsRound.Look
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: SidebarRowConstants.iconTextSpacing) {
            if isTool, look.mark == .tile {
                Image(systemName: symbol).font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(tint)
                    .frame(width: SidebarRowConstants.iconFrameWidth, height: SidebarRowConstants.iconFrameWidth)
                    .background(tint.opacity(0.14), in: .rect(cornerRadius: SpacingTokens.xxs, style: .continuous))
            } else {
                Image(systemName: symbol).font(SidebarRowConstants.iconFont).foregroundStyle(tint)
                    .frame(width: SidebarRowConstants.iconFrameWidth, height: SidebarRowConstants.iconFrameHeight)
            }
            Text(title).font(TypographyTokens.standard).lineLimit(1)
            Spacer(minLength: SpacingTokens.xxs)
            if let trailing { Text(trailing).font(SidebarRowConstants.trailingFont).foregroundStyle(ColorTokens.Text.tertiary) }
            if isTool, look.mark == .arrow || look.mark == .window, look.shows == .always || isHovering {
                Image(systemName: look.mark == .arrow ? "arrow.up.right.square" : "macwindow")
                    .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                    .transition(.opacity)
            }
        }
        .padding(.leading, SidebarRowConstants.rowLeadingPadding)
        .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
        .frame(height: SpacingTokens.lg + SpacingTokens.xxs1)
        .background { if isHovering { RoundedRectangle(cornerRadius: SidebarRowConstants.hoverCornerRadius).fill(ColorTokens.Sidebar.hoverFill) } }
        .padding(.horizontal, SidebarRowConstants.rowOuterHorizontalPadding)
        .contentShape(Rectangle())
        .onHover { hovering in withAnimation(.easeOut(duration: 0.12)) { isHovering = hovering } }
    }
}
