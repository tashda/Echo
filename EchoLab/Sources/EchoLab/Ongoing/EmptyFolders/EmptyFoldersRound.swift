import SwiftUI

/// Round 30.3 · Database folders that are empty. The owner couldn't find Views under a database.
/// Echo loads views (SQLServerSessionAdapter+Metadata), but `ExplorerBlueprintWalker.objectFolderNodes`
/// hides every object folder with no items unless Settings › Sidebar › Show Empty Folders is on
/// (off by default), so a database without views has no Views folder; Synonyms disappears the same way.
///
/// Accepted 2026-10-01: EF1, EL1, OE0, the database really has no views, and ST1 (the setting is
/// removed, the owner's pick over keeping it). Built into Echo as TREE-6.2.
@MainActor
enum EmptyFoldersRound {
    enum Policy: String, CaseIterable {
        case hideAll = "EF0 · Hide every empty folder (today)"
        case keepMain = "EF1 · Always show Tables, Views, Functions and Procedures"
        case showAll = "EF2 · Show every folder, empty or not"

        var summary: String {
            switch self {
            case .hideAll: "What you see now: a folder appears only once it has something in it, unless Show Empty Folders is on."
            case .keepMain: "The four folders every database has in SSMS and DataGrip stay put; the rarer ones (Synonyms, Sequences, Types) still hide when empty."
            case .showAll: "Today's setting turned on for everyone: every folder of the engine, always."
            }
        }
    }

    enum EmptyLook: String, CaseIterable {
        case zero = "EL0 · Like any folder, with 0"
        case dimmed = "EL1 · Dimmed name, no count"
        case dimmedNone = "EL2 · Dimmed, with “None”"
    }

    enum OpenEmpty: String, CaseIterable {
        case placeholder = "OE0 · It opens to a grey “No views” row"
        case noChevron = "OE1 · It can't be opened; the folder has no chevron"
    }

    private struct Folder: Hashable {
        let title: String
        let symbol: String
        let tint: Color
        let count: Int?
        let isMain: Bool
        let isObjects: Bool
    }

    private static let folders: [Folder] = [
        .init(title: "Tables", symbol: "tablecells", tint: Color(nsColor: .systemTeal), count: 83, isMain: true, isObjects: true),
        .init(title: "Views", symbol: "eye", tint: Color(nsColor: .systemIndigo), count: 0, isMain: true, isObjects: true),
        .init(title: "Functions", symbol: "function", tint: ColorTokens.Status.warning, count: 2, isMain: true, isObjects: true),
        .init(title: "Procedures", symbol: "terminal", tint: ColorTokens.Status.error, count: 24, isMain: true, isObjects: true),
        .init(title: "Triggers", symbol: "bolt", tint: Color(nsColor: .systemYellow), count: 8, isMain: false, isObjects: true),
        .init(title: "Synonyms", symbol: "arrow.triangle.branch", tint: Color(nsColor: .systemGray), count: 0, isMain: false, isObjects: true),
        .init(title: "Security", symbol: "shield", tint: Color(nsColor: .systemPurple), count: nil, isMain: false, isObjects: false),
        .init(title: "Database Triggers", symbol: "bolt.horizontal", tint: Color(nsColor: .systemYellow), count: nil, isMain: false, isObjects: false),
        .init(title: "Service Broker", symbol: "tray.2", tint: ColorTokens.Status.info, count: nil, isMain: false, isObjects: false),
        .init(title: "External Resources", symbol: "externaldrive", tint: Color(nsColor: .systemBrown), count: nil, isMain: false, isObjects: false),
    ]

    static let spec = RoundSpec(
        controls: [
            .of("policy", "Empty folders", Policy.self, default: .keepMain,
                question: "Compare the database in Echo today and the Proposal. Which folders should a database always show?",
                recommend: .keepMain,
                why: "You went looking for Views and concluded it was gone; a folder that comes and goes with its contents reads as a bug. The four main folders are where everyone looks first, so they stay; showing every folder (EF2) brings back Synonyms, Sequences and Types on every database, which is the clutter the setting was added to remove.",
                summary: \.summary),
            .of("look", "Empty look", EmptyLook.self, default: .dimmed,
                question: "Look at Views in the Proposal. How should an empty folder look?",
                recommend: .dimmed,
                why: "Dimmed says empty before you read anything, and dropping the count keeps the column of numbers for folders that have something. A 0 looks like a count that failed to load; “None” adds a word to every empty row."),
            .of("open", "Opening it", OpenEmpty.self, default: .placeholder,
                question: "Click Views in the Proposal. What should happen?",
                recommend: .placeholder,
                why: "Every folder in the tree opens, and the grey row confirms it is empty rather than still loading; a folder that ignores the click looks broken. The row is also where “New View” lives in its context menu."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "ccsLDK17 has no views and no synonyms, so neither folder is there.",
                  isEchoToday: true, designWidth: 320, designHeight: 470) { _ in
                FoldersCard(policy: .hideAll, look: .zero, open: .placeholder)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls. Click Views.",
                  designWidth: 320, designHeight: 470) { values in
                FoldersCard(policy: Policy(rawValue: values["policy"]) ?? .keepMain,
                            look: EmptyLook(rawValue: values["look"]) ?? .dimmed,
                            open: OpenEmpty(rawValue: values["open"]) ?? .placeholder)
            },
        ],
        questions: [
            .init(id: "bug", title: "Is Views really empty?",
                  question: "In SSMS, does ccsLDK17 on dkloosql10-p have views? If it does, Echo lost them while loading and this is a bug, not a design question.",
                  choices: [
                      .init(id: "empty", name: "It has no views: decide the folder above"),
                      .init(id: "hasViews", name: "It has views: Echo is losing them (a bug to fix first)"),
                  ],
                  recommended: "empty",
                  why: "The loader asks the server for tables and views together and sorts them by type (sqlserver-nio listTables, type U, S, V, TT); with Show Empty Folders off a database without views looks exactly like your screenshot."),
            .init(id: "setting", title: "The setting",
                  question: "Should Settings › Sidebar › Show Empty Folders stay?",
                  choices: [
                      .init(id: "keep", name: "ST0 · Keep it: on shows every folder, off follows the rule above"),
                      .init(id: "remove", name: "ST1 · Remove it: the rule above is the only behaviour"),
                  ],
                  recommended: "keep",
                  why: "Someone who wants the SSMS layout exactly can still have it, and the rule above makes the default sensible."),
        ],
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "Main folders always, dimmed when empty, opening to a grey row.",
                  values: ["policy": Policy.keepMain.rawValue, "look": EmptyLook.dimmed.rawValue, "open": OpenEmpty.placeholder.rawValue],
                  isRecommended: true),
            .init(id: "ssms", name: "Like SSMS", summary: "Every folder, always, with its count.",
                  values: ["policy": Policy.showAll.rawValue, "look": EmptyLook.zero.rawValue]),
        ]
    )

    /// The server card with ccsLDK17 open, as in the owner's screenshot.
    private struct FoldersCard: View {
        let policy: Policy
        let look: EmptyLook
        let open: OpenEmpty
        @State private var viewsOpen = false

        var body: some View {
            VStack(alignment: .leading, spacing: SpacingTokens.none) {
                LabSHRow(title: "AML")
                LabSHRow(title: "ccsLDK10")
                LabSHRow(title: "ccsLDK17")
                ForEach(visible, id: \.self) { folder in
                    let isEmpty = folder.count == 0
                    LabSHRow(title: folder.title, symbol: folder.symbol, tint: folder.tint.opacity(isEmpty && look != .zero ? 0.45 : 1),
                             indent: SidebarRowConstants.indentStep, trailing: trailing(folder), isDimmed: isEmpty && look != .zero)
                        .contentShape(Rectangle())
                        .onTapGesture { if isEmpty && open == .placeholder { viewsOpen.toggle() } }
                    if isEmpty, viewsOpen, open == .placeholder, folder.title == "Views" {
                        Text("No views").font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.tertiary)
                            .padding(.leading, SidebarRowConstants.indentStep * 2 + SidebarRowConstants.iconFrameWidth)
                            .frame(maxWidth: .infinity, minHeight: SpacingTokens.lg + SpacingTokens.xxs1, alignment: .leading)
                    }
                }
                LabSHRow(title: "ccsLDK20")
            }
            .padding(.vertical, SpacingTokens.xs)
            .workspaceCard()
            .padding(SpacingTokens.sm)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(ColorTokens.Workspace.canvas)
        }

        private var visible: [Folder] {
            folders.filter { folder in
                guard folder.count == 0 else { return true }
                switch policy {
                case .hideAll: return false
                case .keepMain: return folder.isMain
                case .showAll: return true
                }
            }
        }

        private func trailing(_ folder: Folder) -> String? {
            guard let count = folder.count else { return nil }
            guard count == 0 else { return "\(count)" }
            switch look {
            case .zero: return "0"
            case .dimmed: return nil
            case .dimmedNone: return "None"
            }
        }
    }
}
