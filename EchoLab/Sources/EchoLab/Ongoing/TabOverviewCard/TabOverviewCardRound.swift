import SwiftUI

/// Round 35.2 · Tab overview: the card. Echo today (TabPreviewCard, CompactTabPreviewCard): about
/// 200pt wide; the picture is the SQL in grey on an accent gradient (empty tabs say "Empty query");
/// under it a status dot, the title and an Active capsule, then chips (time ago in capitals, rows).
@MainActor
enum TabOverviewCardRound {
    enum Size: String, CaseIterable {
        case today = "CS0 · About 200pt wide (today)"
        case medium = "CS1 · 240pt"
        case large = "CS2 · 300pt, as Safari's"
        var width: CGFloat {
            switch self {
            case .today: 200
            case .medium: 240
            case .large: 300
            }
        }
    }

    static let spec = RoundSpec(
        controls: [
            .of("thumbnail", "Picture", LabTOThumbnail.self, default: .snapshot,
                question: "Look at the nine cards with each picture. Which lets you recognise a tab before reading its title?",
                recommend: .snapshot,
                why: "You find a tab by its shape: an editor over a grid, the Jobs tab's panes, a diagram. A snapshot keeps that; SQL alone makes every query card look alike, and a symbol says only the kind. TP3 is the runner-up if snapshots turn out too small to read."),
            .of("info", "Under the picture", LabTOInfo.self, default: .twoLines,
                question: "Compare what each card says under its picture.",
                recommend: .twoLines,
                why: "Two quiet lines (title; database · status) carry everything today's chips do without three shapes per card; \"57S AGO\" in capitals reads as shouting. Title only hides the database, which is how you tell Query 1 from Query 1."),
            .of("status", "Running and failed", LabTOStatusLook.self, default: .ring,
                question: "Find the running and the failed tab in each.",
                recommend: .ring,
                why: "With nine or thirty cards, an edge in orange or red is visible from across the grid; a 6pt dot needs reading. The ring is only for the two states that need you."),
            .of("size", "Size", Size.self, default: .medium,
                question: "Change the card size and judge legibility against how many fit.",
                recommend: .medium,
                why: "240pt keeps four cards across a 1100pt content area and the snapshot readable; 300pt fits three, which overflows quickly with two servers."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "SQL on a blue wash, title with Active, chips.",
                  isEchoToday: true, isWide: true, designWidth: 760, designHeight: 520) { _ in
                LabTOCardSet(thumbnail: .today, info: .today, status: .dot, width: 200, closeOnHover: false)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls. Hover a card for its close button.",
                  isWide: true, designWidth: 760, designHeight: 520) { values in
                LabTOCardSet(thumbnail: LabTOThumbnail(rawValue: values["thumbnail"]) ?? .snapshot,
                             info: LabTOInfo(rawValue: values["info"]) ?? .twoLines,
                             status: LabTOStatusLook(rawValue: values["status"]) ?? .ring,
                             width: (Size(rawValue: values["size"]) ?? .medium).width, closeOnHover: true)
            },
        ],
        questions: [
            .init(id: "close", title: "Closing from the overview",
                  question: "How do you close a tab from its card?",
                  choices: [
                      .init(id: "menu", name: "CL0 · Right-click › Close (today)"),
                      .init(id: "hover", name: "CL1 · An × on the card's corner on hover, and right-click"),
                      .init(id: "swipe", name: "CL2 · CL1, and a swipe left on a trackpad"),
                  ],
                  recommended: "hover",
                  why: "Safari's overview: the × appears where you point. Swipe-to-close is an iPad gesture that a two-finger scroll can trigger by accident."),
        ],
        exhibitTopic: ("Which card?", "Is the Proposal's card the one for the overview?", "proposal",
                       "A snapshot of the tab with two quiet lines, a coloured edge only for running and failed tabs, 240pt wide."),
        presets: [
            .init(id: "recommended", name: "My recommendation",
                  values: ["thumbnail": LabTOThumbnail.snapshot.rawValue, "info": LabTOInfo.twoLines.rawValue,
                           "status": LabTOStatusLook.ring.rawValue, "size": Size.medium.rawValue], isRecommended: true),
            .init(id: "code", name: "Code cards", values: ["thumbnail": LabTOThumbnail.code.rawValue, "info": LabTOInfo.twoLines.rawValue,
                                                           "status": LabTOStatusLook.badge.rawValue]),
        ]
    )
}

/// The nine sample tabs as cards of one look.
private struct LabTOCardSet: View {
    let thumbnail: LabTOThumbnail
    let info: LabTOInfo
    let status: LabTOStatusLook
    let width: CGFloat
    let closeOnHover: Bool

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: width, maximum: width), spacing: SpacingTokens.md)], spacing: SpacingTokens.md) {
                ForEach(LabTOTab.samples) { tab in
                    LabTOCard(tab: tab, thumbnail: thumbnail, isActive: tab.id == LabTOTab.activeID, info: info, statusLook: status, closeOnHover: closeOnHover)
                        .frame(width: width)
                }
            }
            .padding(SpacingTokens.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.Workspace.canvas)
    }
}
