import SwiftUI

/// Round 51 · Server trail: telling servers apart, and a shelf for minimized cards. The owner likes
/// that a minimized card stays in the list and the trail item opens it, but the trail's two-letter
/// monograms are too generic to find a server in under a second. This round varies what an item
/// looks like (TI), how its name is revealed (NM), how much the user can customise (CU), and where
/// a minimized card can be found again (SH). The trail means "the servers I am connected to"; a
/// shelf means "the cards I tucked away". Changes the rail's item (Window and cards: rail).
@MainActor
enum ServerTrailIdentityRound {
    private static let windowWidth = LayoutTokens.Workspace.treeIdealWidth + SpacingTokens.xxl * 2

    static let spec = RoundSpec(
        controls: [
            .of("style", "Trail item", LabTIStyle.self, default: .disc,
                question: "Look at the Proposal, then at Nine servers. Which item lets you find one server fastest?",
                recommend: .disc,
                why: "Colour is the one cue the eye finds without reading, and a filled disc carries the most of it per item; the letters then settle the two servers that share a colour. TI5 is the best answer when the user has taken the time to pick a symbol, so it is the CU2 customisation level and not the default. The ring and tile are calmer but spend colour on a line or a tint, and TI4 can't tell two servers of one product apart.",
                summary: \.summary),
            .of("names", "Name", LabTINames.self, default: .bubble,
                question: "Hover the items in the Proposal with each. How should a server's name appear?",
                recommend: .bubble,
                why: "A tooltip's delay is exactly the second you want back. The bubble costs nothing when you aren't hovering and shows name and product at once. The widening rail (NM2) is the most complete but covers the tree every time the pointer passes the rail on its way to something else.",
                summary: \.summary),
            .of("shelf", "Minimized cards", LabTIShelf.self, default: .ring,
                question: "Minimize a card (click its header) and bring it back from where it went, with each choice. Where should minimized cards go?",
                recommend: .ring,
                why: "It is the only choice that adds nothing: the server stays in the trail, dimmed and ringed, and the list loses the card it isn't using. A tray (SH4) separates trail and shelf as you described but adds a button and a click to every retrieval; the section and the strips add a second place to look. If trail and shelf must be different things in your mind, SH2 is the closest to the Dock.",
                summary: \.summary),
            .of("custom", "Customization", LabTICustom.self, default: .glyph,
                question: "Open Customize and try each level. How much should the user be able to change?",
                recommend: .glyph,
                why: "Colour alone is already a connection property and does not fix servers of one colour; a symbol or an emoji does (a flame for prod). Your own letters and shapes add four controls for a case the symbol already covers. Everything stays optional, so Automatic users see no change.",
                summary: \.summary),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today",
                  summary: "Monograms in the colour, tooltips, minimized cards staying in the list as header-only cards. Test and norway are minimized: click them.",
                  isEchoToday: true, designWidth: windowWidth, designHeight: 520) { _ in
                LabTIWindow(look: .today)
            },
            .init(id: "proposal", title: "Proposal",
                  summary: "Built from the controls. Click a card's header to minimize it; click its item, chip or row to bring it back.",
                  designWidth: windowWidth, designHeight: 520) { values in
                LabTIWindow(look: LabTILook(values))
            },
            .init(id: "nine", title: "Nine servers",
                  summary: "The chosen item on nine servers, next to their names: can you find a server without reading?",
                  designWidth: 380, designHeight: 520) { values in
                LabTINineServers(look: LabTILook(values))
            },
            .init(id: "customize", title: "Customize",
                  summary: "What the user would see to make an item theirs, at the chosen level, with a live preview among neighbours.",
                  designWidth: 460, designHeight: 520) { values in
                LabTICustomizer(look: LabTILook(values))
            },
        ],
        questions: [
            .init(id: "where", title: "Where to customize",
                  question: "Where does the user change a server's colour, symbol and letters?",
                  choices: [
                      .init(id: "menu", name: "WH0 · A Customize Appearance popover from the trail item's right-click menu", summary: nil),
                      .init(id: "sheet", name: "WH1 · Only in the connection's sheet", summary: nil),
                      .init(id: "both", name: "WH2 · Both: the popover and the connection's sheet", summary: nil),
                  ],
                  recommended: "both",
                  why: "You notice that a server looks wrong where you see it: the trail. The popover writes the same connection properties as the sheet, so the two cannot disagree, and the sheet remains where anyone looks for a connection's settings."),
            .init(id: "scope", title: "Where the look appears",
                  question: "Once a server has its own mark, where else should it show?",
                  choices: [
                      .init(id: "rail", name: "WS0 · The trail only", summary: nil),
                      .init(id: "tabs", name: "WS1 · The trail, the tabs and the footer's server pill", summary: nil),
                      .init(id: "all", name: "WS2 · Also the card header and Manage Connections", summary: nil),
                  ],
                  recommended: "all",
                  why: "A mark you chose to find a server is most useful where you act on it: in the tab you run a query from and in the list of connections. Drawing it in one place only makes a custom look feel unfinished."),
        ],
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "Filled discs, a bubble on hover, minimized cards stay as rings.",
                  values: ["style": LabTIStyle.disc.rawValue, "names": LabTINames.bubble.rawValue, "shelf": LabTIShelf.ring.rawValue, "custom": LabTICustom.glyph.rawValue],
                  isRecommended: true),
            .init(id: "emoji", name: "Your own marks", summary: "Symbols and emoji on tinted discs, with a tray for minimized cards.",
                  values: ["style": LabTIStyle.glyph.rawValue, "names": LabTINames.bubble.rawValue, "shelf": LabTIShelf.tray.rawValue, "custom": LabTICustom.full.rawValue]),
            .init(id: "dock", name: "Like the Dock", summary: "Labelled discs and chips under the cards.",
                  values: ["style": LabTIStyle.labelled.rawValue, "names": LabTINames.tooltip.rawValue, "shelf": LabTIShelf.stripBottom.rawValue, "custom": LabTICustom.colour.rawValue]),
            .init(id: "arc", name: "Like Arc", summary: "A rail that opens to names, tiles and a Minimized section.",
                  values: ["style": LabTIStyle.tile.rawValue, "names": LabTINames.expand.rawValue, "shelf": LabTIShelf.section.rawValue, "custom": LabTICustom.glyph.rawValue]),
        ]
    )
}
