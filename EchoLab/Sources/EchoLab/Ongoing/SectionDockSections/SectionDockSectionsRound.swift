import SwiftUI

/// Round 19 · Section dock, page 3: how many sections a dock holds, how SQL Server's eight are
/// grouped, and what happens to sections that don't fit (their items under » can't be
/// right-clicked today). Changes TREE-3.4 (More) and TREE-3.5 (which sections show).
@MainActor
enum SectionDockSectionsRound {
    private static let width = LayoutTokens.Workspace.treeIdealWidth + SpacingTokens.xxxl
    private static let height = SpacingTokens.xxxl * 9

    static let spec = RoundSpec(
        controls: [
            .of("grouping", "SQL Server's sections", LabSDGrouping.self, default: .ssms,
                question: "Open each of Test MSSQL's sections in the Proposal. Do the groups make sense to someone who knows SSMS?",
                recommend: .ssms,
                why: "It is SSMS's own grouping: Database Snapshots sit at the end of Databases, Linked Servers and Server Triggers in Server Objects, and Integration Services with the other tools. Five sections, so nothing needs More. G2 puts unrelated things together in Server Objects; G0 needs More.",
                summary: \.summary),
            .of("limit", "Most icons", LabSDLimit.self, default: .five,
                question: "Set 4, 5 and 6 with the narrowest sidebar you use. How many icons fit before they feel cramped?",
                recommend: .five,
                why: "Five fit comfortably at the sidebar's 260pt default, and every database type fits in five once SQL Server is grouped, so the rule becomes \"never more than five sections per type\". Six crowds the capsule at 200pt; four forces More on PostgreSQL."),
            .of("overflow", "Sections that don't fit", LabSDOverflow.self, default: .moreSection,
                question: "Set Most icons to 4 (or SQL Server's sections to G0) so something is left out, then reach a left-out section and right-click it.",
                recommend: .moreSection,
                why: "Left-out sections become ordinary folders in the card, so they open, show their counts and right-click like everything else. M1 reaches the actions but only through nested menus; M3 hides icons off the edge, M4 makes every icon smaller, and M5 adds a second row to every card.",
                summary: \.summary),
        ],
        actions: [
            .init(id: "reset", title: "Reset the trees", symbol: "arrow.counterclockwise") { $0["resetToken"] = UUID().uuidString },
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Round 16 as built: SQL Server's eight sections, four in the capsule and four under a » menu that can't be right-clicked.",
                  isEchoToday: true, designWidth: width, designHeight: height) { values in
                tree(LabSDOptions.today, values)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls. Right-click the icons and whatever » leads to.",
                  designWidth: width, designHeight: height) { values in
                tree(options(values), values)
            },
            .init(id: "types", title: "Every database type", summary: "SQL Server, PostgreSQL, MySQL and SQLite with the proposal's sections and limit.",
                  isWide: true, designWidth: 700, designHeight: 620) { values in
                LabSDEveryType(options: options(values), resetToken: values["resetToken"]).background(ColorTokens.Workspace.canvas)
            },
        ],
        questions: [
            .init(id: "groupName", title: "The grouped section's name",
                  question: "What should the section holding Linked Servers and Server Triggers be called?",
                  choices: [.init(id: "serverObjects", name: "Server Objects"), .init(id: "objects", name: "Objects"), .init(id: "server", name: "Server")],
                  recommended: "serverObjects",
                  why: "It is SSMS's name for exactly this folder, so SQL Server users find it where they expect. \"Objects\" clashes with database objects; \"Server\" is vague."),
            .init(id: "rule", title: "A rule for every type",
                  question: "Should \"never more than five sections per database type\" be a rule for Echo's blueprints, so no type needs More by default?",
                  choices: [.init(id: "yes", name: "Yes, five at most"), .init(id: "no", name: "No, allow more")],
                  recommended: "yes",
                  why: "Every type fits today (SQL Server once grouped), and the rule keeps the dock readable as Echo adds tools: new ones go inside a section, not beside it. More stays for sections you add yourself."),
        ],
        presets: [
            .init(id: "recommended", name: "SSMS five, More as a section", summary: "My recommendation.", values: [
                "grouping": LabSDGrouping.ssms.rawValue, "limit": LabSDLimit.five.rawValue, "overflow": LabSDOverflow.moreSection.rawValue,
            ], isRecommended: true),
            .init(id: "overflowing", name: "See More at work", summary: "Four icons, so More has something to show.", values: [
                "grouping": LabSDGrouping.ssms.rawValue, "limit": LabSDLimit.four.rawValue, "overflow": LabSDOverflow.moreSection.rawValue,
            ]),
            .init(id: "submenus", name: "Menu with submenus", summary: "Eight sections; » gives each a submenu of its actions.", values: [
                "grouping": LabSDGrouping.today.rawValue, "limit": LabSDLimit.four.rawValue, "overflow": LabSDOverflow.menuWithActions.rawValue,
            ]),
            .init(id: "all", name: "Everything visible", summary: "Eight sections, every one an icon, on two rows.", values: [
                "grouping": LabSDGrouping.today.rawValue, "limit": LabSDLimit.five.rawValue, "overflow": LabSDOverflow.secondRow.rawValue,
            ]),
        ]
    )

    private static func options(_ values: RoundValues) -> LabSDOptions {
        var options = LabSDOptions()
        // The other pages' recommendations, so the trees look and move the way they would ship.
        options.switchMotion = .fadeThrough
        options.switchScroll = .jump
        options.neighbours = .holdPosition
        options.capsule = .edgedGlass
        options.weight = .medium
        options.currentMark = .pill
        options.sectionName = .underName
        options.hover = .fill
        options.grouping = LabSDGrouping(rawValue: values["grouping"]) ?? .ssms
        options.limit = LabSDLimit(rawValue: values["limit"]) ?? .five
        options.overflow = LabSDOverflow(rawValue: values["overflow"]) ?? .moreSection
        return options
    }

    private static func tree(_ options: LabSDOptions, _ values: RoundValues) -> some View {
        LabSDTreeView(servers: LabSDSamples.servers(grouping: options.grouping), options: options, resetToken: values["resetToken"])
            .padding(SpacingTokens.sm)
            .background(ColorTokens.Workspace.canvas)
    }
}
