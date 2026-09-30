import SwiftUI

/// Round 14's section dock, written in the round blueprint (the pilot for the new round design).
/// Each topic is one question with the options side by side; the rest of the dock stays as
/// Echo has it today.
@MainActor
enum DockRound {
    static let blueprint = RoundBlueprint(
        intro: "TC1 was accepted: an icon row pinned under the server's name switches what the card shows. What is left is how it looks: the icon style, whether the dock shows a title, and the edge under it.",
        topics: [
            .init(
                id: "icons", title: "Icon style",
                question: "Which icon style should the dock and the rows use by default?",
                howToTry: "Look at the dock icons and the row icons in light and dark, then switch section in the dock.",
                options: [
                    option(id: "duotone", name: "Duotone (IC2)", isEchoToday: true,
                           summary: "The outline in the role's colour over its fill at low opacity. The default in Echo.",
                           icons: .duotone, labels: .iconsOnly, edge: .soft),
                    option(id: "mono", name: "Mono line (IC1)", summary: "One quiet line colour. Stays available as a setting.",
                           icons: .mono, labels: .iconsOnly, edge: .soft),
                ]),
            .init(
                id: "labels", title: "Dock labels",
                question: "Should the dock show which section you are in as text?",
                howToTry: "Switch between Databases, Security and Agent and read where you are.",
                options: [
                    option(id: "icons-only", name: "Icons only", isEchoToday: true,
                           summary: "Five icons; the current one sits on the grey selection fill.",
                           icons: .duotone, labels: .iconsOnly, edge: .soft),
                    option(id: "current-title", name: "Icons and current title", summary: "The current section's name appears next to the icons.",
                           icons: .duotone, labels: .currentTitle, edge: .soft),
                ]),
            .init(
                id: "edge", title: "Edge under the dock",
                question: "How should rows look as they scroll under the pinned dock?",
                howToTry: "Scroll the rows slowly in each card and watch the dock's lower edge.",
                options: [
                    option(id: "soft", name: "Soft edge", isEchoToday: true,
                           summary: "Only a soft blur: no background and no line.",
                           icons: .duotone, labels: .iconsOnly, edge: .soft),
                    option(id: "hard", name: "Hard edge", summary: "A crisp edge where the rows meet the dock.",
                           icons: .duotone, labels: .iconsOnly, edge: .hard),
                ]),
        ])

    private static func option(
        id: String, name: String, isEchoToday: Bool = false, summary: String,
        icons: LabDockIconMode, labels: LabDockLabels, edge: LabDockEdge
    ) -> RoundBlueprint.Option {
        RoundBlueprint.Option(
            id: id, name: name, summary: summary, isEchoToday: isEchoToday,
            designWidth: LayoutTokens.DesignLabRound14.dockCardWidth,
            designHeight: LayoutTokens.DesignLabRound14.dockCardHeight
        ) {
            DockOptionSpecimen(icons: icons, labels: labels, edge: edge)
        }
    }
}

private struct DockOptionSpecimen: View {
    let icons: LabDockIconMode
    let labels: LabDockLabels
    let edge: LabDockEdge
    @Environment(\.echoMotion) private var motion

    var body: some View {
        LabRound14DockCard(iconMode: icons, labels: labels, edge: edge, animation: motion.standard)
    }
}
