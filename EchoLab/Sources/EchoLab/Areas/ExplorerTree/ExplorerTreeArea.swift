import Observation
import SwiftUI

/// Settings the Explorer tree specimen shares with its controls.
@Observable @MainActor
final class ExplorerTreeSpecimenSettings {
    /// The state the Spec page forces ("hoverRow", "hoverObject"); nil shows the rows at rest.
    var forced: String?
    /// Settings › Appearance › Icon colour: Colourful (duotone rows, the default) or Monochrome.
    var iconMode: LabDockIconMode = LabPrefs.load("explorerTree.iconMode", default: LabDockIconMode.duotone) {
        didSet { LabPrefs.save(iconMode, key: "explorerTree.iconMode") }
    }
    /// Settings › Appearance › Dock icons: Mono (the default) or Duotone.
    var dockMode: LabDockIconMode = LabPrefs.load("explorerTree.dockMode", default: LabDockIconMode.mono) {
        didSet { LabPrefs.save(dockMode, key: "explorerTree.dockMode") }
    }
}

/// The Explorer tree as it is in Echo today: server cards with S4 Quiet rows, duotone icons and
/// the section dock (decisions 2026-09-29 and 2026-09-30; plan D1, D2).
@MainActor
enum ExplorerTreeArea {
    private static let settings = ExplorerTreeSpecimenSettings()

    static let area = LabArea(
        id: "explorer-tree",
        title: "Explorer tree",
        symbol: "list.bullet.indent",
        summary: "Each server sits on its own card: quiet 28pt rows, duotone icons, and a dock of section icons pinned under the server's name.",
        asBuilt: AsBuiltPage(
            verification: .init(
                level: .code, commit: "cbc72fb1", date: "2026-10-02",
                note: "Read from SidebarRow, SidebarRowConstants, ExplorerDock, ExplorerDockRow, ObjectBrowserRowView+Headers, ObjectBrowserSidebarView+Dock, ExplorerMotion, ExplorerTreeVeilLayer, ExplorerTreeScrollState, ExplorerBlueprint+SQLServer and the tokens, as of round 19 and the 2026-10-01 smoothness work. The specimen is a self-contained copy of the server card. 2026-10-02: checked the commits since dce125e1 (38e19682 is already in the spec as TREE-1 Placed, not stacked; round 52 and 51 are the rail, in the Window area; the others touch menus or the rail files only). Round 51 left the closed card as the header only: SH5 (minimised cards leaving the list) is not built. 2026-10-02 (round 53): rewritten from the code for the title banner (TREE-2.7), the thirty colours (2.8), the chevron on motion.standard, and the removal of the tab and footer dots (round 49)."),
            stageHeight: 540,
            behaviours: [
                .init(trigger: "Hover a row", result: "A folder's icon turns into a chevron and its count appears. Nothing else moves."),
                .init(trigger: "Click a folder", result: "It opens or closes; the rows below slide and fade, like the native outline."),
                .init(trigger: "Look at a server's name", result: "The title banner (round 53): the server's colour in full from the card's top through the dock, small capitals over a 22pt name (the dock's section while open, the engine while closed), a hairline edge, and the dock's icons straight on the colour, the current one filled. Settings › Appearance › Server Header changes the typeface, size, line above, edge and text colour, and still offers Wash, Plain, Bar, Glass Plate and Banner; Server Header Color the accent or none (rounds 30.1, 50 and 53)."),
                .init(trigger: "Right-click a server's name › Color", result: "Thirty colours, each with a dark variant; the header, rail and tabs change at once. The Customize Appearance popover adds a colour well for any colour."),
                .init(trigger: "Click a server's name", result: "Opening, the edge glides down while the dock grows out of the header and the rows wait under a veil in the card's colour, which fades away once the edge settles; closing, the veil covers the rows, then the edge glides up as the dock shrinks back (round 46). The cards below follow the edge. Closed, the name, product line and chevron are centred in the card. The chevron sits at the trailing edge, centred on the two lines; it shows on hover while open and always while closed, and turns a quarter on the house spring (rounds 30.2 and 53)."),
                .init(trigger: "Click an object", result: "Grey selection fill with the row's icon in its accent."),
                .init(trigger: "Click a dock icon", result: "A veil in the card's colour fades over the rows (0.12s); under it the new section swaps in and the card's edge moves to its size (0.28s, no overshoot), the view jumps to where that section was left, and the veil fades away (0.22s). Rows never slide or show outside the card, and the window holds still meanwhile. A section not shown before doesn't scroll; the header's second line names the current section."),
                .init(trigger: "Hover a dock icon", result: "An icon that isn't the current one grows 12%."),
                .init(trigger: "More (») in the dock", result: "Shows the sections the capsule leaves out (it holds at most five) as ordinary folders."),
                .init(trigger: "A card gets shorter", result: "A spacer under the last card keeps the bottom where it was, so the cards above don't move; it gives the room back as you scroll up. Folding a card is the exception: if you were scrolled into it, its header first comes to its own place, and when the tree is left shorter than the view, the view glides back with the fold."),
                .init(trigger: "Scroll the rows", result: "Rows pass under the pinned name and dock; once they do, a light wash of the card colour appears behind them and the rows blur and fade at the edge. The capsule has a hairline edge and a soft shadow."),
                .init(trigger: "Right-click", result: "A menu for that node kind, from the database type's blueprint."),
                .init(trigger: "Schema prefix", result: "Dimmed on tables outside the default schema."),
                .init(trigger: "A row that opens a tab", result: "Agent Jobs Overview, Security Overview, Management's tools (a sheet too) end in a grey ↗, always. Every SQL Server Security, the server's and each database's, starts with Security Overview (round 38)."),
                .init(trigger: "A database with no views", result: "Views is still there, dimmed with no count; it opens to a grey “No views” row. Tables, Views, Functions and Procedures always show; Synonyms, Sequences and the other rare folders only when they have something (round 30.3)."),
            ],
            motions: [
                .init(name: "Folder open and close", curve: "ease in-out", duration: "0.22s", note: "echoMotion.expand"),
                .init(name: "Server card fold", curve: "ease in-out", duration: "0.22s", note: "echoMotion.expand: the card's edge, the veil, the dock's growth and the header's glide on one curve (rounds 30.2 and 46)"),
                .init(name: "Server card open: veil out", curve: "ease out", duration: "0.22s", note: "ExplorerDockSwitchTiming.fadeIn, after the edge"),
                .init(name: "Server card close: veil in", curve: "ease out", duration: "0.12s", note: "ExplorerDockSwitchTiming.fadeOut, before the edge"),
                .init(name: "Reveal in the tree", curve: "smooth", duration: "0.40s", note: "echoMotion.reveal, scrolling to a picked object"),
                .init(name: "Hover fill", curve: "ease out", duration: "0.12s", note: "echoMotion.hover"),
                .init(name: "Switch dock section: veil in", curve: "ease out", duration: "0.12s", note: "ExplorerDockSwitchTiming.fadeOut; scaled by the Motion speed setting"),
                .init(name: "Switch dock section: card edge", curve: "smooth, no overshoot", duration: "0.28s", note: "echoMotion.dockEdge; only the switching card animates"),
                .init(name: "Switch dock section: veil out", curve: "ease out", duration: "0.22s", note: "ExplorerDockSwitchTiming.fadeIn; after the swap and the jump to the remembered position"),
                .init(name: "Dock icon hover", curve: "ease out", duration: "0.12s", note: "grows 12%; echoMotion.hover"),
            ],
            measurements: [
                .init(label: "Row height", value: "28pt in a 29pt slot", token: "medium density"),
                .init(label: "Icon frame", value: "18 × 16pt", token: "SidebarRowConstants.iconFrameWidth / Height"),
                .init(label: "Icon to label", value: "8pt", token: "SidebarRowConstants.iconTextSpacing"),
                .init(label: "Indent per level", value: "16pt", token: "SidebarRowConstants.indentStep"),
                .init(label: "Row padding", value: "6pt leading · 8pt trailing", token: "rowLeadingPadding / rowTrailingPadding"),
                .init(label: "Row corner", value: "8pt", token: "LayoutTokens.Workspace.treeRowCornerRadius"),
                .init(label: "Server name", value: "Bold 13pt at the default size", token: "SidebarRowConstants.serverHeaderFont"),
                .init(label: "Product line", value: "11pt monospaced digits, tertiary: product and release, then the current section", token: "SidebarRowConstants.trailingFont"),
                .init(label: "Dock capsule", value: "22 · 24 · 28 · 32pt by size, glass, 0.5pt edge at 80%, shadow black 8% radius 4", token: "LayoutTokens.ExplorerDock"),
                .init(label: "Dock icons", value: "Medium weight, 14pt at the default size", token: "ExplorerDockRow.iconFont"),
                .init(label: "Sections in the capsule", value: "at most five", token: "ExplorerDock.capsuleLimit"),
                .init(label: "Folder chevron", value: "Semibold 11pt", token: "SidebarRowConstants.chevronFont"),
                .init(label: "Server chevron", value: "Semibold 11pt, trailing, centred on the name and product line", token: "SidebarRowConstants.sectionChevronFont"),
                .init(label: "Closed card", value: "The header slot (49pt at the default size) plus 4pt, its contents centred", token: "serverHeaderExtraHeight / treeCardBottomPadding"),
                .init(label: "Row label", value: "13pt at the default density (compact 10, small 11, large 15)", token: "SidebarRow.densityLabelFont"),
                .init(label: "Row icon", value: "13pt light in a 18 × 16pt frame at the default density", token: "SidebarRow.densityIconFont / densityIconFrameWidth"),
                .init(label: "Card corners", value: "16pt (setting: 10 to 26)", token: "LayoutTokens.Workspace.cardCornerRadius"),
                .init(label: "Card edge", value: "0.5pt at 35% separator", token: "cardEdgeWidth / cardEdgeOpacity"),
                .init(label: "Row icons", value: "Colourful (duotone, softened 22%) by default; Monochrome is a setting; objects are always grey", token: "SidebarIconColorMode"),
                .init(label: "Dock icons", value: "Mono by default; Duotone is a setting", token: "SidebarDockIconStyle"),
                .init(label: "Title banner", value: "The server's colour at 92% to 100% over the header and dock (96pt at the default size), 0.5pt white hairline at 35%", token: "ServerTitleBannerFill"),
                .init(label: "Header wash", value: "The server's colour at 20%, fading to clear over the header and dock (86pt at the default size); the default until round 53", token: "ServerHeaderBackdrop"),
            ],
            rules: [
                .init(text: "Every server has its own opaque card",
                      why: "The tree is content, so it follows the editor card's tokens; glass is only for controls.",
                      rounds: ["decided.window-canvas-and-cards"]),
                .init(text: "S4 Quiet rows",
                      why: "No chevron column, light symbols and roomy rows read like Finder and Linear. Tahoe, Tiles, Structure, Detailed and Path were rejected.",
                      rounds: ["decided.tree-card-s4-quiet"]),
                .init(text: "A dock of icons under the server's name",
                      why: "It switches sections without long scrolling and remembers each one's place. Every other layout (TC2 to TC9) was rejected.",
                      rounds: ["ported.Round 14 · section dock", "ongoing.server-card-r16", "ongoing.section-dock-capsule-r19"]),
                .init(text: "Switching fades through instead of gliding (S3)", why: "Rows that slide past each other read as noise; a quick fade out and a gentler fade in keeps the place.", rounds: ["ongoing.section-dock-switching-r19"]),
                .init(text: "SQL Server in five sections, as SSMS groups them", why: "The capsule holds at most five; Database Snapshots, Server Objects and Integration Services move into their SSMS homes.", rounds: ["ongoing.section-dock-sections-r19"]),
                .init(text: "Colourful duotone row icons by default, grey dock icons",
                      why: "Tiles, letters and dots were rejected; a Recraft icon set is planned, with SF Symbols drawn duotone until then. The dock stays grey with an accent current icon unless you choose Duotone.",
                      rounds: ["ported.Round 14 · section dock"]),
                .init(text: "A server card folds while its rows fade",
                      why: "Today the rows faded while the card snapped, so for a moment they floated on the canvas. The card's edge now moves with them and cuts them (CM2); a spring, rows rolling up and a cascade were rejected.",
                      rounds: ["ongoing.server-header-collapse-r30"]),
                .init(text: "A server's header in its colour",
                      why: "The header was too quiet. A wash of the server's own colour gives it presence and tells production from test at a glance; the same colour marks the rail, its tabs and the footer pill, so you know where Run will go. The style and colour are settings.",
                      rounds: ["ongoing.server-header-look-r30"]),
                .init(text: "A banner with a title is the default header",
                      why: "The wash was quiet; a banner in full colour with small capitals over a large name tells servers apart at a glance, and the section it names shows what the card is showing. A closed card names the engine instead, since it shows no section. Rounded corners were left out of the edge choices.",
                      rounds: ["ongoing.server-header-polish-r50", "ongoing.server-header-custom-r53"]),
                .init(text: "The main folders never disappear",
                      why: "The owner went looking for Views and thought it was gone. Tables, Views, Functions and Procedures always show, dimmed when empty; hiding every empty folder and showing every folder were rejected, and the setting was removed.",
                      rounds: ["ongoing.empty-folders-r30"]),
                .init(text: "No pinned path header",
                      why: "It cost space and added blur; the dock does the job of orientation.",
                      rounds: ["decided.tree-sticky-header"]),
            ],
            code: [
                "Echo/Sources/Features/ObjectBrowser/Blueprint/ExplorerBlueprint+*.swift",
                "Echo/Sources/Features/ObjectBrowser/Views/Components/ExplorerRowModels.swift",
                "Echo/Sources/Features/ObjectBrowser/Views/Components/ExplorerDock.swift",
                "Echo/Sources/Shared/DesignSystem/Components/SidebarRow.swift",
                "Echo/Sources/Features/ObjectBrowser/Views/Components/ObjectBrowserSidebarView+Fold.swift",
                "Packages/EchoDesignSystem/Sources/EchoDesignSystem/Explorer/ExplorerTreeFoldTransition.swift",
            ]
        ) {
            ExplorerTreeSpecimen(settings: settings)
        }
        .controls {
            ExplorerTreeControls(settings: settings)
        },
        spec: ExplorerTreeSpec.spec(settings: settings)
    )
}

struct ExplorerTreeControls: View {
    @Bindable var settings: ExplorerTreeSpecimenSettings

    var body: some View {
        HStack(spacing: SpacingTokens.md) {
            Picker("Row icons", selection: $settings.iconMode) {
                Text("Colourful (default)").tag(LabDockIconMode.duotone)
                Text("Monochrome").tag(LabDockIconMode.mono)
            }
            .pickerStyle(.segmented)
            .frame(width: 360)
            Picker("Dock icons", selection: $settings.dockMode) {
                Text("Mono (default)").tag(LabDockIconMode.mono)
                Text("Duotone").tag(LabDockIconMode.duotone)
            }
            .pickerStyle(.segmented)
            .frame(width: 300)
            Spacer()
        }
    }
}
