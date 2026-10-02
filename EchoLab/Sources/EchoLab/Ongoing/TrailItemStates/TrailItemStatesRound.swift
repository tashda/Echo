import SwiftUI

/// Round 55 · The trail: connected, minimized and recent servers. Revision 2 follows the owner's rules:
/// connected servers keep today's look (full colour, the white selection disc and its animation) and
/// get nothing added; nothing connected is dimmed or greyed. A minimized server therefore has no
/// mark: it moves below a hairline in the connected pill. Recent servers, which are not connected, are
/// dimmed in a pill of their own; clicking one connects it and it glides up into the connected pill. A
/// server in neither connects from its own button, which is not a +. Round 54's flight is accepted and
/// waits for this. Changes the rail's items (Window and cards: rail).
@MainActor
enum TrailItemStatesRound {
    private static let width = LayoutTokens.Workspace.treeIdealWidth + SpacingTokens.xxxl * 2

    static let spec = RoundSpec(
        controls: [
            .of("divider", "The hairline", LabTSDivider.self, default: .line,
                question: "Minimize a card (click its header) and watch its item go below the line; click it to bring it back. Which divider?",
                recommend: .line,
                why: "A short line is enough to say two groups without drawing a second pill, and it leaves the pill's glass uninterrupted. The full line reads as a table rule; the gap alone is the quietest but loses the cue when only one server is minimized.",
                summary: \.summary),
            .of("form", "The connect button", LabTSConnectForm.self, default: .circle,
                question: "Compare where the button sits.",
                recommend: .circle,
                why: "Connected servers, recent servers and a way to any other server are three different things; three objects says so. The glyph inside the last pill (FM1) is today's + with a new icon and reads as one more server. The bare glyph (FM2) is the quietest, and loses the click target that glass gives.",
                summary: \.summary),
            .of("icon", "The glyph", LabTSConnectIcon.self, default: .rack,
                question: "Press the button's glyph in each form. Which says connecting to a server and not adding one?",
                recommend: .rack,
                why: "The button opens a searchable list of saved servers plus Manage and Quick Connect; the rack is the one picture of what is in it. The bolt is only Quick Connect, and the magnifier is a search, which is the first thing in the list but not its purpose. It must not be a +, which means new.",
                summary: \.summary),
            .of("recent", "A recent server", LabTSRecentLook.self, default: .dim38),
            .of("count", "How many recents", LabTSCount.self, default: .five),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today",
                  summary: "One pill, a dashed ring on a minimized server, a + at its foot. Click a card's header.",
                  isEchoToday: true, designWidth: width, designHeight: 460) { _ in
                LabTSWindow(look: .today)
            },
            .init(id: "proposal", title: "Proposal",
                  summary: "Click a card's header to minimize it (its item glides below the hairline) and the item to bring it back; click a recent server to connect it; right-click a connected one to disconnect.",
                  designWidth: width, designHeight: 460) { values in
                LabTSWindow(look: LabTSLook(values))
            },
        ],
        questions: [
            .init(id: "setting", title: "Recent servers setting",
                  question: "Should the recents pill be optional?",
                  choices: [
                      .init(id: "on", name: "SE0 · On, with a setting to turn it off and set how many", summary: nil),
                      .init(id: "off", name: "SE1 · Off, with a setting to turn it on", summary: nil),
                      .init(id: "none", name: "SE2 · Always on", summary: nil),
                  ],
                  recommended: "on",
                  why: "Some people want a trail of only what is connected; for someone with twelve servers the recents are what makes it useful. One row in Settings › Appearance › Server Trail."),
            .init(id: "disconnect", title: "Disconnecting",
                  question: "A connected server's right-click menu has Disconnect. Where does it go?",
                  choices: [
                      .init(id: "recents", name: "DC0 · To the top of the recents pill, dimmed", summary: nil),
                      .init(id: "gone", name: "DC1 · It leaves the trail", summary: nil),
                  ],
                  recommended: "recents",
                  why: "The server you just closed is the one most likely to be needed again in a minute."),
        ],
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "A short hairline, recents in their own pill, a glass circle with a server rack.",
                  values: ["divider": LabTSDivider.line.rawValue, "form": LabTSConnectForm.circle.rawValue, "icon": LabTSConnectIcon.rack.rawValue],
                  isRecommended: true),
            .init(id: "bolt", name: "Quick", summary: "A bolt, glass circle, a full hairline.",
                  values: ["divider": LabTSDivider.full.rawValue, "form": LabTSConnectForm.circle.rawValue, "icon": LabTSConnectIcon.bolt.rawValue]),
            .init(id: "quiet", name: "Quiet", summary: "No line, a bare magnifier.",
                  values: ["divider": LabTSDivider.gap.rawValue, "form": LabTSConnectForm.bare.rawValue, "icon": LabTSConnectIcon.search.rawValue]),
        ]
    )
}
