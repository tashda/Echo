import SwiftUI

/// Round 19 · Section dock, page 2: the capsule's look. The owner found round 16's glass too
/// subtle, almost white. Changes TREE-3.1 (capsule), TREE-3.2 (current icon), TREE-3.3 (other
/// icons).
@MainActor
enum SectionDockCapsuleRound {
    private static let width = LayoutTokens.Workspace.treeIdealWidth + SpacingTokens.xxxl
    private static let height = SpacingTokens.xxxl * 9

    static let spec = RoundSpec(
        controls: [
            .of("capsule", "Capsule", LabSDCapsuleStyle.self, default: .edgedGlass,
                question: "Compare the styles in the gallery, then try your favourites in the Proposal while scrolling rows under the capsule, in light and dark. Which reads as a control without shouting?",
                recommend: .edgedGlass,
                why: "It keeps the Liquid Glass you liked, but a hairline edge and a soft shadow give it an outline even when there is only white card behind it. Close call with C2, which adds a grey fill that makes the glass itself look heavier. C3 and C4 drop the glass; C7 and C9 lose the control shape.",
                summary: \.summary),
            .of("weight", "Icon weight", LabSDIconWeight.self, default: .medium,
                question: "Change the weight at Default and Large. Which weight holds its own on the capsule next to the bold server name?",
                recommend: .medium,
                why: "Medium matches the weight macOS 26 toolbars use for their glass buttons, and it stands up next to the bold name without competing with it. Regular looks faint on glass; semibold and bold turn the dock into the loudest thing in the card."),
            .of("size", "Icon size", LabSDIconSize.self, default: .today,
                question: "With five icons, does one step larger read better, or does it crowd the capsule?",
                recommend: .today,
                why: "The size already follows the sidebar size setting; medium weight gains the presence a larger size would, without crowding five icons. Pick larger only if the icons still read small at Default."),
            .of("currentMark", "Current section", LabSDCurrentMark.self, default: .pill,
                question: "Switch sections a few times. Which mark makes the current section obvious at a glance?",
                recommend: .pill,
                why: "The accent colour alone is a small change on a busy capsule; a grey pill behind it makes the current section readable even for colour-blind users and in mono. The filled symbol changes the icon's shape; the dot is easy to miss."),
            .of("sectionName", "Section name", LabSDSectionName.self, default: .underName,
                question: "Should the current section's name be written somewhere, so the icons never have to be guessed?",
                recommend: .underName,
                why: "\"SQL Server 2022 · Security\" names the section in the line the header already has, so nothing grows and nothing moves. Beside its icon makes the capsule's icons jump as it widens; above the rows costs a row in every card."),
            .of("hover", "Hover", LabSDHover.self, default: .fill,
                question: "Move the pointer across the icons. Should they react?",
                recommend: .fill,
                why: "A grey circle is how toolbar and glass buttons answer the pointer in macOS 26, and it shows the click target. Growing icons feel playful for a control you use all day."),
            .of("density", "Sidebar size", LabSDDensity.self, default: .medium),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Round 16 as built: clear glass, regular 14pt icons, the current one in the accent colour.",
                  isEchoToday: true, designWidth: width, designHeight: height) { values in
                tree(today(values))
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls. Scroll so rows pass under the capsule.",
                  designWidth: width, designHeight: height) { values in
                tree(options(values))
            },
            .init(id: "gallery", title: "Every capsule style", summary: "All ten styles with rows behind them, drawn with the weight, size, mark and name set in the controls.",
                  isWide: true, designWidth: 700, designHeight: 620) { values in
                LabSDStyleGallery(options: options(values)).background(ColorTokens.Workspace.canvas)
            },
        ],
        presets: [
            .init(id: "recommended", name: "Edged glass, medium, pill", summary: "My recommendation.", values: [
                "capsule": LabSDCapsuleStyle.edgedGlass.rawValue, "weight": LabSDIconWeight.medium.rawValue, "size": LabSDIconSize.today.rawValue,
                "currentMark": LabSDCurrentMark.pill.rawValue, "sectionName": LabSDSectionName.underName.rawValue, "hover": LabSDHover.fill.rawValue,
            ], isRecommended: true),
            .init(id: "xcode", name: "Xcode", summary: "The navigator bar: no capsule, accent icon, hairline.", values: [
                "capsule": LabSDCapsuleStyle.bar.rawValue, "weight": LabSDIconWeight.regular.rawValue, "currentMark": LabSDCurrentMark.accent.rawValue,
                "sectionName": LabSDSectionName.none.rawValue, "hover": LabSDHover.none.rawValue,
            ]),
            .init(id: "segmented", name: "Segmented", summary: "A grey track with a raised white pill, like the system control.", values: [
                "capsule": LabSDCapsuleStyle.raisedPill.rawValue, "weight": LabSDIconWeight.medium.rawValue, "currentMark": LabSDCurrentMark.pill.rawValue,
                "hover": LabSDHover.fill.rawValue,
            ]),
            .init(id: "quiet", name: "Quiet fill", summary: "No glass: a grey track and a pill.", values: [
                "capsule": LabSDCapsuleStyle.filledTrack.rawValue, "weight": LabSDIconWeight.medium.rawValue, "currentMark": LabSDCurrentMark.pill.rawValue,
            ]),
            .init(id: "labelled", name: "Named", summary: "Frosted glass with the current section's name beside its icon.", values: [
                "capsule": LabSDCapsuleStyle.frostedGlass.rawValue, "weight": LabSDIconWeight.medium.rawValue, "sectionName": LabSDSectionName.inCapsule.rawValue,
            ]),
        ]
    )

    private static func today(_ values: RoundValues) -> LabSDOptions {
        var options = LabSDOptions.today
        options.density = LabSDDensity(rawValue: values["density"]) ?? .medium
        return options
    }

    private static func options(_ values: RoundValues) -> LabSDOptions {
        var options = today(values)
        // The switching page's recommendation, so the trees move the same way.
        options.switchMotion = .fadeThrough
        options.switchScroll = .jump
        options.neighbours = .holdPosition
        options.capsule = LabSDCapsuleStyle(rawValue: values["capsule"]) ?? .edgedGlass
        options.weight = LabSDIconWeight(rawValue: values["weight"]) ?? .medium
        options.size = LabSDIconSize(rawValue: values["size"]) ?? .today
        options.currentMark = LabSDCurrentMark(rawValue: values["currentMark"]) ?? .pill
        options.sectionName = LabSDSectionName(rawValue: values["sectionName"]) ?? .underName
        options.hover = LabSDHover(rawValue: values["hover"]) ?? .fill
        return options
    }

    private static func tree(_ options: LabSDOptions) -> some View {
        LabSDTreeView(servers: LabSDSamples.servers(grouping: .today), options: options)
            .padding(SpacingTokens.sm)
            .background(ColorTokens.Workspace.canvas)
    }
}
