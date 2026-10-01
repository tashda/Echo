import SwiftUI

/// Round 16, written as a `RoundSpec`: two exhibits (Echo today, the proposal) driven by the
/// same controls, plus the questions that don't have a control.
@MainActor
enum LabServerCardRound {
    private static let width = LayoutTokens.Workspace.treeIdealWidth + SpacingTokens.xl + SpacingTokens.sm * 2
    private static let height = SpacingTokens.xxxl * 9 + SpacingTokens.sm * 2

    static let spec = RoundSpec(
        controls: [
            .of("header", "Header style", LabSCHeader.self, default: .glass,
                question: "Scroll the Proposal so rows pass under H5's capsule, at Default and Large. Does it read like Xcode's navigator icons, with the rows blurred behind the glass?",
                recommend: .glass,
                why: "You picked H5 and asked for Xcode's navigator icons: the icons now spread across a capsule the card's width, the current one in the accent colour with no fill, and rows show through it blurred. H1 is the same bar without glass if the capsule feels heavy.",
                summary: \.summary),
            .of("pinning", "Pinned", LabSCPinning.self, default: .nameAndIcons,
                question: "Scroll the Proposal with each. Should the server's name stay above the capsule, or scroll away and leave only the icons, as in Xcode?",
                recommend: .nameAndIcons,
                why: "Several servers are stacked in one column, so a pinned capsule alone doesn't say whose sections it switches. Icons only is closer to Xcode and saves about 30pt; the rail still shows the server."),
            .of("version", "Version", LabSCVersion.self, default: .below,
                question: "SQL Server shows as \"SQL Server 2022\" (the full build is in the tooltip). Under, beside, or only in the tooltip?",
                recommend: .below,
                why: "You picked it: under the name it stays visible without crowding it, and the tooltip keeps the exact build."),
            .of("edge", "Edge under the header", LabSCEdge.self, default: .blurRows,
                question: "Scroll the Proposal and the System edge exhibit side by side. Does Blur rows now look like the system's own soft edge?",
                recommend: .blurRows,
                why: "You picked it and asked for it to look native. It now copies the system's soft edge (rows stay under the header, blurring and fading towards the top over a light wash) and still works with stacked cards, which the real system edge can't.",
                summary: \.summary),
            .of("switch", "Switching sections", LabSCSwitch.self, default: .crossfade,
                question: "Click the dock icons. Crossfade, Slide or Instant instead of rows dropping in from the top?",
                recommend: .crossfade,
                why: "You picked it: calm, and it keeps your place. Slide suggests an order between sections that they don't have; instant feels abrupt."),
            .of("initialLoad", "Initial load", LabSCInitialLoad.self, default: .foldersFirst,
                question: "Set Server to Slow and press Reset and connect again (Databases loads), then open Security and Agent Jobs for the first time. Which spinner, and what inside the card?",
                recommend: .foldersFirst,
                why: "The card shows its real shape at once: Security's folders appear straight away, spinning in their count slots, so nothing is replaced when the items arrive. Where a level is only items (Databases, jobs) it is one spinner row (I2). I1 and I5 leave the card empty, and I3 is a pattern the tree doesn't use anywhere else.",
                summary: \.summary),
            .of("iconSpinner", "Spinner on the icon", LabSCIconSpinner.self, default: .hide,
                question: "With a slow server, open a section for the first time. Should its dock icon spin as well as the card?",
                recommend: .hide,
                why: "The spinner in the card is where you are looking, and a second one on the selected icon doubles it. I1 always spins the icon, since the card shows nothing else."),
            .of("loading", "Opening a folder", LabSCLoading.self, default: .skeleton,
                question: "With a slow server, press Reset and connect again, then open Tables in a database. Quiet skeleton, or Keep + spinner?",
                recommend: .skeleton,
                why: "You picked the skeleton; your note was about the initial load, now a separate control. It avoids a layout jump inside a tree that is already there, and a fast server never shows it.",
                summary: \.summary),
            .of("counts", "Counts", LabSCCounts.self, default: .always,
                question: "Hover a folder while it loads. On hover, always (quiet), or hidden?",
                recommend: .always,
                why: "You picked it: quiet counts that are always there can't blink while a folder loads. This changes the S4 Quiet rule that counts appear on hover."),
            .of("selection", "Selection", LabSCSelection.self, default: .symmetric,
                question: "Select a row. Symmetric insets fix the fill touching the left edge.",
                recommend: .symmetric,
                why: "It fixes the fill touching the left edge and matches the hover fill's insets."),
            .of("dockIcons", "Dock icons", LabSCIconStyle.self, default: .mono),
            .of("treeIcons", "Tree icons", LabSCIconStyle.self, default: .duotone),
            .of("density", "Sidebar size", LabSCDensity.self, default: .medium),
            .of("latency", "Server", LabSCLatency.self, default: .slow),
            .of("speed", "Speed", LabSpeed.self, default: .standard),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "The server card as it is built now, with the same two servers.",
                  isEchoToday: true, designWidth: width, designHeight: height) { values in
                column(options(values, today: true), values, today: true)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls. Scroll, switch sections, open folders, right-click the icons.",
                  designWidth: width, designHeight: height) { values in
                column(options(values, today: false), values, today: false)
            },
            .init(id: "system", title: "System edge", summary: "The proposal with macOS's own soft scroll edge, to judge how native Blur rows looks. It only works with one server in the column.",
                  designWidth: width, designHeight: height + SpacingTokens.xl) { values in
                column(systemEdge(values), values, today: false)
            },
        ],
        questions: [
            .init(id: "customising", title: "Customising",
                  question: "Right-click an icon: its section's own menu, then Dock. Customize Dock sets the icons for every server of the type or this server only, and the dock's icon style apart from the tree's.",
                  choices: [.init(id: "works", name: "Works as intended"), .init(id: "changes", name: "Needs changes")],
                  recommended: "works",
                  why: "Customising lives in the same right-click menu as the rest of the section, so nothing new to learn. Change it only if you didn't find it."),
            .init(id: "postgres", title: "PostgreSQL",
                  question: "postgres18 gets Activity, Management and Tablespaces from tools Echo already has. Anything missing or wrongly grouped?",
                  choices: [.init(id: "right", name: "Looks right"), .init(id: "wrong", name: "Something is missing or wrong")],
                  recommended: "right",
                  why: "Activity, Management and Tablespaces come from tools Echo already has, grouped the way SQL Server's sections are."),
        ],
        presets: [
            .init(id: "picks", name: "Your picks + folders first", summary: "Your round 16 picks, with I4 for the initial load.", values: [
                "header": LabSCHeader.glass.rawValue, "pinning": LabSCPinning.nameAndIcons.rawValue, "version": LabSCVersion.below.rawValue,
                "edge": LabSCEdge.blurRows.rawValue, "switch": LabSCSwitch.crossfade.rawValue, "initialLoad": LabSCInitialLoad.foldersFirst.rawValue,
                "iconSpinner": LabSCIconSpinner.hide.rawValue, "loading": LabSCLoading.skeleton.rawValue, "counts": LabSCCounts.always.rawValue,
                "selection": LabSCSelection.symmetric.rawValue], isRecommended: true),
            .init(id: "defaults", name: "Navigator + blur", summary: "My first recommendation: H1 without glass.", values: [
                "header": LabSCHeader.navigator.rawValue, "version": LabSCVersion.below.rawValue, "edge": LabSCEdge.blurRows.rawValue,
                "switch": LabSCSwitch.crossfade.rawValue, "loading": LabSCLoading.skeleton.rawValue, "counts": LabSCCounts.hover.rawValue,
                "selection": LabSCSelection.symmetric.rawValue]),
            .init(id: "quiet", name: "Quietest", summary: "One line, version in the tooltip, fade, instant, hidden counts.", values: [
                "header": LabSCHeader.oneLine.rawValue, "version": LabSCVersion.tooltip.rawValue, "edge": LabSCEdge.fadeRows.rawValue,
                "switch": LabSCSwitch.instant.rawValue, "loading": LabSCLoading.keep.rawValue, "counts": LabSCCounts.hidden.rawValue]),
            .init(id: "native", name: "Most native", summary: "System segmented control and the system scroll edge.", values: [
                "header": LabSCHeader.segmented.rawValue, "edge": LabSCEdge.system.rawValue, "switch": LabSCSwitch.crossfade.rawValue]),
            .init(id: "glass", name: "Glass dock", summary: "A Liquid Glass capsule that slides between sections.", values: [
                "header": LabSCHeader.glass.rawValue, "edge": LabSCEdge.blurRows.rawValue, "switch": LabSCSwitch.slide.rawValue]),
        ]
    )

    private static func options(_ v: RoundValues, today: Bool) -> LabSCOptions {
        let tree = LabSCIconStyle(rawValue: v["treeIcons"]) ?? .duotone
        return LabSCOptions(
            header: today ? .today : (LabSCHeader(rawValue: v["header"]) ?? .glass),
            edge: today ? .material : (LabSCEdge(rawValue: v["edge"]) ?? .blurRows),
            switchMotion: today ? .today : (LabSCSwitch(rawValue: v["switch"]) ?? .crossfade),
            loading: today ? .shimmer : (LabSCLoading(rawValue: v["loading"]) ?? .skeleton),
            initialLoad: today ? .today : (LabSCInitialLoad(rawValue: v["initialLoad"]) ?? .foldersFirst),
            iconSpinner: today ? .hide : (LabSCIconSpinner(rawValue: v["iconSpinner"]) ?? .hide),
            pinning: today ? .nameAndIcons : (LabSCPinning(rawValue: v["pinning"]) ?? .nameAndIcons),
            latency: LabSCLatency(rawValue: v["latency"]) ?? .slow,
            dockIcons: today ? tree : (LabSCIconStyle(rawValue: v["dockIcons"]) ?? .mono),
            treeIcons: tree,
            density: LabSCDensity(rawValue: v["density"]) ?? .medium,
            counts: today ? .hover : (LabSCCounts(rawValue: v["counts"]) ?? .always),
            selection: today ? .today : (LabSCSelection(rawValue: v["selection"]) ?? .symmetric),
            version: today ? .beside : (LabSCVersion(rawValue: v["version"]) ?? .below),
            speed: LabSpeed(rawValue: v["speed"]) ?? .standard)
    }

    /// The proposal as it would be with the system's scroll edge (one server per column).
    private static func systemEdge(_ v: RoundValues) -> LabSCOptions {
        var options = options(v, today: false)
        options.edge = .system
        return options
    }

    private static func column(_ options: LabSCOptions, _ v: RoundValues, today: Bool) -> some View {
        let dock: Binding<LabSCIconStyle> = today ? .constant(options.dockIcons)
            : Binding(get: { LabSCIconStyle(rawValue: v["dockIcons"]) ?? .mono }, set: { v["dockIcons"] = $0.rawValue })
        let tree: Binding<LabSCIconStyle> = today ? .constant(options.treeIcons)
            : Binding(get: { LabSCIconStyle(rawValue: v["treeIcons"]) ?? .duotone }, set: { v["treeIcons"] = $0.rawValue })
        return LabSCTreeColumn(servers: LabSCServer.samples, options: options, dockIcons: dock, treeIcons: tree)
            .frame(width: LayoutTokens.Workspace.treeIdealWidth + SpacingTokens.xl, height: SpacingTokens.xxxl * 9)
            .padding(SpacingTokens.sm)
    }
}
