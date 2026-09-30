import SwiftUI

/// Round 16, written as a `RoundSpec`: two exhibits (Echo today, the proposal) driven by the
/// same controls, plus the questions that don't have a control.
@MainActor
enum LabServerCardRound {
    private static let width = LayoutTokens.Workspace.treeIdealWidth + SpacingTokens.xl + SpacingTokens.sm * 2
    private static let height = SpacingTokens.xxxl * 9 + SpacingTokens.sm * 2

    static let spec = RoundSpec(
        controls: [
            .of("header", "Header style", LabSCHeader.self, default: .navigator,
                question: "Try each with Sidebar size at Default and Large. Which reads best: the name with icons under it, one line, a menu, or glass?",
                recommend: .navigator,
                why: "It follows Xcode's navigator bar: small icons spread across, the current one in the accent colour, no fill. It scales to any number of sections, keeps the name as the only bold line, and needs no glass on the card (H5) or mono-only control (H2).",
                summary: \.summary),
            .of("version", "Version", LabSCVersion.self, default: .below,
                question: "SQL Server shows as \"SQL Server 2022\" (the full build is in the tooltip). Under, beside, or only in the tooltip?",
                recommend: .below,
                why: "The full name is long; under the server's name it stays visible without crowding it, and the tooltip keeps the exact build."),
            .of("edge", "Edge under the header", LabSCEdge.self, default: .blurRows,
                question: "Scroll the Proposal. Compare Blur rows and Fade rows with Today. System edge is macOS's own, but only works with one server per column.",
                recommend: .blurRows,
                why: "No tint and no edge, and it works with stacked server cards. The system edge is nicer but only possible when one server fills the column.",
                summary: \.summary),
            .of("switch", "Switching sections", LabSCSwitch.self, default: .crossfade,
                question: "Click the dock icons. Crossfade, Slide or Instant instead of rows dropping in from the top?",
                recommend: .crossfade,
                why: "Calm and it keeps your place. Slide suggests an order between sections that they don't have; instant feels abrupt."),
            .of("loading", "Loading", LabSCLoading.self, default: .skeleton,
                question: "Set Server to Slow, press Reset loading, then open Security and Tables. Quiet skeleton or Keep + spinner? With a Fast server the skeleton never shows.",
                recommend: .skeleton,
                why: "Rows shaped like real rows avoid a layout jump, and it only appears after a quarter second, so fast servers never flash it.",
                summary: \.summary),
            .of("counts", "Counts", LabSCCounts.self, default: .hover,
                question: "Hover a folder while it loads. On hover, always (quiet), or hidden?",
                recommend: .hover,
                why: "It matches the S4 Quiet decision: counts appear on hover and stay out of the way otherwise."),
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
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls above. Scroll, switch sections, open folders, right-click the icons.",
                  designWidth: width, designHeight: height) { values in
                column(options(values, today: false), values, today: false)
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
            .init(id: "defaults", name: "Navigator + blur", summary: "My recommendation on every question.", values: [
                "header": LabSCHeader.navigator.rawValue, "version": LabSCVersion.below.rawValue, "edge": LabSCEdge.blurRows.rawValue,
                "switch": LabSCSwitch.crossfade.rawValue, "loading": LabSCLoading.skeleton.rawValue, "counts": LabSCCounts.hover.rawValue,
                "selection": LabSCSelection.symmetric.rawValue], isRecommended: true),
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
            header: today ? .today : (LabSCHeader(rawValue: v["header"]) ?? .navigator),
            edge: today ? .material : (LabSCEdge(rawValue: v["edge"]) ?? .blurRows),
            switchMotion: today ? .today : (LabSCSwitch(rawValue: v["switch"]) ?? .crossfade),
            loading: today ? .shimmer : (LabSCLoading(rawValue: v["loading"]) ?? .skeleton),
            latency: LabSCLatency(rawValue: v["latency"]) ?? .slow,
            dockIcons: today ? tree : (LabSCIconStyle(rawValue: v["dockIcons"]) ?? .mono),
            treeIcons: tree,
            density: LabSCDensity(rawValue: v["density"]) ?? .medium,
            counts: today ? .hover : (LabSCCounts(rawValue: v["counts"]) ?? .hover),
            selection: today ? .today : (LabSCSelection(rawValue: v["selection"]) ?? .symmetric),
            version: today ? .beside : (LabSCVersion(rawValue: v["version"]) ?? .below),
            speed: LabSpeed(rawValue: v["speed"]) ?? .standard)
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
