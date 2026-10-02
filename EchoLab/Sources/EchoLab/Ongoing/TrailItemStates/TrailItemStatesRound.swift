import SwiftUI

/// Round 55 · Trail items: open, minimized and recent servers. The owner dislikes the dashed ring on
/// a minimized server (round 51's SH5, round 54's landing) and asks how an open server and a
/// minimized one should be told apart now that both are connected, and whether the trail should
/// also hold recently connected servers (dimmed, in the same pill or a second one) that connect
/// when clicked and move into the connected group. Round 54's flight is accepted and waits for this.
/// Changes the rail's items (Window and cards: rail).
@MainActor
enum TrailItemStatesRound {
    private static let width = LayoutTokens.Workspace.treeIdealWidth + SpacingTokens.xxxl * 2

    static let spec = RoundSpec(
        controls: [
            .of("mark", "Open and minimized", LabTSMark.self, default: .disc,
                question: "Look at all twelve in Every mark, then click cards and items in the Proposal. How should a trail item show that its card is open, and not minimized?",
                recommend: .disc,
                why: "A soft disc of the server's colour behind an open server is the one that stays inside the item: no dot or bar to add to the pill's width, nothing that looks like a status. It layers with what the trail already has (the white disc is the selected server, the tint is every open one, a plain item is minimized), and it is made of the colour you already chose. The dot (ST2) is the better-known idea but reads as 'running', which every item is; the grey (ST9) loses the colour that finds a server.",
                summary: \.summary),
            .of("recents", "Recent servers", LabTSRecents.self, default: .samePill,
                question: "Click a recent server in each, then right-click a connected one and choose Disconnect. Should the trail show recent servers, and where?",
                recommend: .samePill,
                why: "You are right that everything in the trail is connected: so recents should be unmistakably something else, which a divider and dimming say in one glass object. Two pills double the glass and make a second place to look for servers; the clock button keeps the trail pure but adds the click that this is meant to remove. Connecting from there needs no menu: the server breathes while it connects, then glides up into the connected group.",
                summary: \.summary),
            .of("recentLook", "A recent server", LabTSRecentLook.self, default: .dim,
                question: "Compare how a recent server looks.",
                recommend: .dim,
                why: "Dimmed to 38% keeps the colour, which is how you find a server in under a second; grey letters lose it, and the clock explains the dimming but adds a mark to every recent.",
                summary: \.summary),
            .of("count", "How many recents", LabTSCount.self, default: .five),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today",
                  summary: "A dashed ring on a minimized server, no recents. Click a card's header.",
                  isEchoToday: true, designWidth: width, designHeight: 440) { _ in
                LabTSWindow(look: .today)
            },
            .init(id: "proposal", title: "Proposal",
                  summary: "Click a card's header to minimize it and its item to open it; click a recent server to connect it; right-click a connected one to disconnect.",
                  designWidth: width, designHeight: 440) { values in
                LabTSWindow(look: LabTSLook(values))
            },
            .init(id: "marks", title: "Every mark",
                  summary: "Each mark on four items: open and selected, open, minimized and recent.",
                  designWidth: 700, designHeight: 620) { values in
                LabTSMarksGallery(look: LabTSLook(values))
            },
        ],
        questions: [
            .init(id: "setting", title: "A setting",
                  question: "If recent servers are in the trail, should they be optional?",
                  choices: [
                      .init(id: "on", name: "SE0 · On, with a setting to turn them off", summary: nil),
                      .init(id: "off", name: "SE1 · Off, with a setting to turn them on", summary: nil),
                      .init(id: "none", name: "SE2 · Always on, no setting", summary: nil),
                  ],
                  recommended: "on",
                  why: "Some people will want a trail of only what is connected; for a person with twelve servers the recents are what makes the trail useful. A setting in Settings › Appearance › Server Trail (Show Recent Servers and how many) costs one row."),
            .init(id: "disconnect", title: "Disconnecting",
                  question: "A connected server's right-click menu has Disconnect. Where should a disconnected server go?",
                  choices: [
                      .init(id: "recents", name: "DC0 · To the top of the recents, dimmed", summary: nil),
                      .init(id: "gone", name: "DC1 · It leaves the trail", summary: nil),
                  ],
                  recommended: "recents",
                  why: "The server you just closed is the one you are most likely to need again in a minute."),
        ],
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "A soft disc for open servers, five dimmed recents in the same pill.",
                  values: ["mark": LabTSMark.disc.rawValue, "recents": LabTSRecents.samePill.rawValue, "recentLook": LabTSRecentLook.dim.rawValue],
                  isRecommended: true),
            .init(id: "pure", name: "Pure", summary: "Only connected servers, an open server marked by a dot.",
                  values: ["mark": LabTSMark.dot.rawValue, "recents": LabTSRecents.none.rawValue]),
            .init(id: "two", name: "Two pills", summary: "Connected servers and recents in a pill each, the colour doing the work.",
                  values: ["mark": LabTSMark.grey.rawValue, "recents": LabTSRecents.twoPills.rawValue, "recentLook": LabTSRecentLook.dim.rawValue]),
            .init(id: "button", name: "A clock", summary: "A pill of connected servers and a clock for the rest.",
                  values: ["mark": LabTSMark.weight.rawValue, "recents": LabTSRecents.button.rawValue]),
        ]
    )
}
