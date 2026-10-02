import SwiftUI

/// Round 53 · Server card header: customization and the chevron. Takes round 50's chosen header
/// (F5: a banner, an eyebrow over a large name, a hairline edge, the icon menu without a capsule
/// or pill, the selected icon filled) as the baseline. Offers customizations a user could have
/// besides the colour and the symbol, in levels, and nine collapse chevrons that animate.
/// Changes TREE-2.1, TREE-2.4 (chevron) and Settings › Appearance › Server Header.
@MainActor
enum ServerHeaderCustomRound {
    private static let width = LayoutTokens.Workspace.treeIdealWidth + SpacingTokens.xl

    static let spec = RoundSpec(
        controls: [
            .of("level", "Customization", LabHCLevel.self, default: .standard,
                question: "Set each level and look at Settings, then the card. How much of the header should a user be able to change?",
                recommend: .standard,
                why: "Typeface and size are what people actually want to change; the edge and the eyebrow are what make the card theirs. Automatic text colour is the one that is needed rather than nice: an amber or yellow banner with white type fails contrast. The full set (ten rows) mostly adds ways to make the card worse, so I would hold it back until someone asks for it.",
                summary: \.summary),
            .of("chevron", "Chevron", LabHCChevron.self, default: .turn,
                question: "Click the header of each card in Chevrons, then the Proposal. Which collapse control should the card have?",
                recommend: .turn,
                why: "A chevron that turns is what Finder and Mail do, so nobody needs to learn it, and the turn is the animation you said was missing. CH3 (the flip) is the one with character, drawn as a path that flattens and flips, and is my second choice if you want the card to feel designed; the handle (CH5) and the label (CH4) are better ideas for a card that collapses more often than ours does.",
                summary: \.summary),
            .of("shows", "Chevron shows", LabHCChevronShows.self, default: .hover,
                question: "Hover in and out of the Proposal's header, open and collapsed. When should the chevron be visible?",
                recommend: .hover,
                why: "You decided this in round 30.2 (CV0): a collapsed card must say it can open, an open one only needs the chevron when you reach for it. Always shown (CV1) at 70% is the alternative if the chevron should be discoverable."),
            .of("motion", "Chevron motion", LabHCMotion.self, default: .bounce,
                question: "Collapse and open the Proposal with each motion. How should the chevron and the fold move?",
                recommend: .bounce,
                why: "It is the house spring that opened the trail, so cards and rail move as one family. Smooth is the one to pick if the fold is felt as too playful on a card this tall."),
            .of("family", "Typeface", LabHCFamily.self, default: .system),
            .of("size", "Size", LabHCSize.self, default: .medium),
            .of("weight", "Weight", LabHCWeight.self, default: .semibold),
            .of("align", "Alignment", LabHCAlign.self, default: .leading),
            .of("density", "Spacing", LabHCDensity.self, default: .standard),
            .of("eyebrow", "Line above the name", LabHCEyebrow.self, default: .section),
            .of("fill", "Fill", LabHCFill.self, default: .gradient),
            .of("edge", "Edge", LabHCEdge.self, default: .hairline),
            .of("text", "Text colour", LabHCText.self, default: .white),
            .of("iconSize", "Icon size", LabHCIconSize.self, default: .medium),
            .of("colour", "Colour", LabHRColour.self, default: .sample),
            .of("sample", "Server", LabSHSample.self, default: .production),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today",
                  summary: "The wash header with the glass icon menu (Echo's default).",
                  isEchoToday: true, designWidth: width, designHeight: 400) { values in
                LabHCColumn { LabHRCard(server: sample(values), look: .today) }
            },
            .init(id: "proposal", title: "Proposal",
                  summary: "Your preset from round 50, at the chosen level. Click the header to collapse it, an icon to switch section.",
                  designWidth: width, designHeight: 400) { values in
                LabHCColumn { LabHCCard(server: sample(values), look: LabHCLook(values)) }
            },
            .init(id: "settings", title: "Settings",
                  summary: "Settings › Appearance › Server Header at the chosen level; every row changes the card above it.",
                  designWidth: 460, designHeight: 640) { values in
                LabHCSettings(values: values, server: sample(values))
            },
            .init(id: "chevrons", title: "Chevrons",
                  summary: "All nine, with the chosen visibility and motion. Click each header; hover to see them.",
                  designWidth: 700, designHeight: 620) { values in
                let look = LabHCLook(values)
                LabHCGallery(variants: LabHCChevron.allCases.map { ($0.rawValue, look.with(chevron: $0)) }, server: sample(values))
            },
            .init(id: "presets", title: "Four ways to customise",
                  summary: "What a user could make of it: calm, editorial, monitor, loud. They are the presets on the left.",
                  designWidth: 700, designHeight: 620) { values in
                LabHCGallery(variants: presetLooks(values), server: sample(values), rowLimit: 2)
            },
            .init(id: "three", title: "Three servers",
                  summary: "Production, test and a PostgreSQL server in one column.",
                  designWidth: width, designHeight: 560) { values in
                LabHCColumn {
                    LabHCCard(server: .production, look: LabHCLook(values), rowLimit: 3)
                    LabHCCard(server: .test, look: LabHCLook(values), rowLimit: 2)
                    LabHCCard(server: .development, look: LabHCLook(values), rowLimit: 2)
                }
            },
        ],
        questions: [
            .init(id: "scope", title: "Per server or for all",
                  question: "Should the type settings be one setting for every server card, or per server?",
                  choices: [
                      .init(id: "all", name: "SC0 · One setting for every server card, in Settings › Appearance", summary: nil),
                      .init(id: "server", name: "SC1 · Per server, in the connection's sheet", summary: nil),
                      .init(id: "both", name: "SC2 · A global default, overridable per server", summary: nil),
                  ],
                  recommended: "all",
                  why: "Colour and symbol identify a server, so they are per server; type is how the whole sidebar looks, and cards with different typefaces side by side read as an accident. SC2 is more machinery than anyone will use."),
        ],
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "Your preset, Standard customization, the chevron turns on the house spring.",
                  values: ["level": LabHCLevel.standard.rawValue, "chevron": LabHCChevron.turn.rawValue, "shows": LabHCChevronShows.hover.rawValue,
                           "motion": LabHCMotion.bounce.rawValue],
                  isRecommended: true),
            .init(id: "calm", name: "Calm", summary: "Small, medium weight, compact, flat, a sharp edge.",
                  values: calm),
            .init(id: "editorial", name: "Editorial", summary: "Large serif, centred, roomy, an engine eyebrow.",
                  values: editorial),
            .init(id: "monitor", name: "Monitor", summary: "Monospaced, compact, an engine and section eyebrow.",
                  values: monitor),
            .init(id: "loud", name: "Loud", summary: "Large heavy rounded, a frosted fill.",
                  values: loud),
        ]
    )

    // The customisations the presets stand for; the gallery draws the same four.
    private static let calm: [String: String] = [
        "level": LabHCLevel.full.rawValue, "family": LabHCFamily.system.rawValue, "size": LabHCSize.small.rawValue,
        "weight": LabHCWeight.medium.rawValue, "density": LabHCDensity.compact.rawValue, "fill": LabHCFill.flat.rawValue,
        "edge": LabHCEdge.sharp.rawValue, "align": LabHCAlign.leading.rawValue]
    private static let editorial: [String: String] = [
        "level": LabHCLevel.full.rawValue, "family": LabHCFamily.serif.rawValue, "size": LabHCSize.large.rawValue,
        "weight": LabHCWeight.semibold.rawValue, "density": LabHCDensity.roomy.rawValue, "align": LabHCAlign.centred.rawValue,
        "eyebrow": LabHCEyebrow.engine.rawValue, "edge": LabHCEdge.hairline.rawValue, "fill": LabHCFill.gradient.rawValue]
    private static let monitor: [String: String] = [
        "level": LabHCLevel.full.rawValue, "family": LabHCFamily.mono.rawValue, "size": LabHCSize.small.rawValue,
        "weight": LabHCWeight.semibold.rawValue, "density": LabHCDensity.compact.rawValue, "eyebrow": LabHCEyebrow.engineSection.rawValue,
        "align": LabHCAlign.leading.rawValue, "fill": LabHCFill.flat.rawValue, "edge": LabHCEdge.hairline.rawValue]
    private static let loud: [String: String] = [
        "level": LabHCLevel.full.rawValue, "family": LabHCFamily.rounded.rawValue, "size": LabHCSize.large.rawValue,
        "weight": LabHCWeight.heavy.rawValue, "density": LabHCDensity.roomy.rawValue, "fill": LabHCFill.frosted.rawValue,
        "edge": LabHCEdge.rounded.rawValue, "align": LabHCAlign.leading.rawValue, "eyebrow": LabHCEyebrow.section.rawValue]

    private static func presetLooks(_ values: RoundValues) -> [(title: String, look: LabHCLook)] {
        let current = LabHCLook(values)
        return [("Calm", calm), ("Editorial", editorial), ("Monitor", monitor), ("Loud", loud)].map { name, preset in
            let fixed = RoundValues(fixed: preset)
            var look = LabHCLook(fixed)
            look.chevron = current.chevron; look.shows = current.shows; look.motion = current.motion; look.colour = current.colour
            return (name, look)
        }
    }

    private static func sample(_ values: RoundValues) -> LabSHServer {
        (LabSHSample(rawValue: values["sample"]) ?? .production).server
    }
}
