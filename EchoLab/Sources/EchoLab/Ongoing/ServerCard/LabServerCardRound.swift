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
                summary: \.summary),
            .of("version", "Version", LabSCVersion.self, default: .below,
                question: "SQL Server shows as \"SQL Server 2022\" (the full build is in the tooltip). Under, beside, or only in the tooltip?"),
            .of("edge", "Edge under the header", LabSCEdge.self, default: .blurRows,
                question: "Scroll the Proposal. Compare Blur rows and Fade rows with Today. System edge is macOS's own, but only works with one server per column.",
                summary: \.summary),
            .of("switch", "Switching sections", LabSCSwitch.self, default: .crossfade,
                question: "Click the dock icons. Crossfade, Slide or Instant instead of rows dropping in from the top?"),
            .of("loading", "Loading", LabSCLoading.self, default: .skeleton,
                question: "Set Server to Slow, press Reset loading, then open Security and Tables. Quiet skeleton or Keep + spinner? With a Fast server the skeleton never shows.",
                summary: \.summary),
            .of("counts", "Counts", LabSCCounts.self, default: .hover,
                question: "Hover a folder while it loads. On hover, always (quiet), or hidden?"),
            .of("selection", "Selection", LabSCSelection.self, default: .symmetric,
                question: "Select a row. Symmetric insets fix the fill touching the left edge."),
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
                  choices: [.init(id: "works", name: "Works as intended"), .init(id: "changes", name: "Needs changes")]),
            .init(id: "postgres", title: "PostgreSQL",
                  question: "postgres18 gets Activity, Management and Tablespaces from tools Echo already has. Anything missing or wrongly grouped?",
                  choices: [.init(id: "right", name: "Looks right"), .init(id: "wrong", name: "Something is missing or wrong")]),
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
