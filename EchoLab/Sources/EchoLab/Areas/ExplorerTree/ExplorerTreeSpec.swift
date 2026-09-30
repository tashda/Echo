import SwiftUI

/// The Explorer tree by piece, each with a stable ID (`TREE-3.2`). Values are read from
/// `SidebarRowConstants`, `SidebarRow`, `ExplorerDock*` and `LayoutTokens`. Numbers are never
/// reused; a retired element stays, struck through.
@MainActor
enum ExplorerTreeSpec {
    private static let rows = "Echo/Sources/Shared/DesignSystem/Components/SidebarRow.swift"
    private static let constants = "Echo/Sources/Features/ObjectBrowser/Views/Components/ExplorerRowModels.swift"
    private static let components = "Echo/Sources/Features/ObjectBrowser/Views/Components/"
    private static let round14 = "ported.Round 14 · section dock"
    private static let round16 = "ongoing.server-card-r16"
    private static let r19Switching = "ongoing.section-dock-switching-r19"
    private static let r19Capsule = "ongoing.section-dock-capsule-r19"
    private static let r19Sections = "ongoing.section-dock-sections-r19"

    static func spec(settings: ExplorerTreeSpecimenSettings) -> AreaSpec {
        AreaSpec(code: "TREE", stageHeight: 400, parts: parts) { ExplorerTreeSpecimen(settings: settings) }
            .controls { ExplorerTreeControls(settings: settings) }
            .onState { settings.forced = $0 }
    }

    private static let parts: [SpecPart] = [
        SpecPart(number: "1", name: "Server card", summary: "Each server has a card of its own in the column.", elements: [
            SpecElement(number: "1.1", name: "Card", summary: "An opaque workspace card, the same as the editor's.", groups: [
                .material(.row("Fill", "opaque", token: "ColorTokens.Workspace.card", swatch: ColorTokens.Workspace.card),
                          .row("Glass", "none: glass is only for controls"),
                          .row("Edge", "0.5pt at 35% separator", token: "cardEdgeWidth / cardEdgeOpacity"),
                          .row("Shadow", "black 12%, blur 10, y 4", token: "ShadowTokens.workspaceCard")),
                .layout(.row("Corner", "16pt continuous (setting: 10 to 26)", token: "LayoutTokens.Workspace.cardCornerRadius"),
                        .row("Width", "260pt ideal, 200 to 480", token: "LayoutTokens.Workspace.treeIdealWidth / Min / Max")),
            ], rounds: ["decided.window-canvas-and-cards"], files: ["Echo/Sources/Features/ObjectBrowser/Views/Components/ExplorerTreeCardsLayer.swift"]),
            SpecElement(number: "1.2", name: "One card per server", summary: "Servers are never merged into one list; a server's card is as tall as its rows.", groups: [
                .behaviour(.row("Rail", "Clicking a server in the rail jumps to its card; the rail marks the card at the top while you scroll"),
                           .row("Holding view (N2)", "when a card gets shorter, a spacer under the last card keeps the bottom where it was, so the cards above don't move; it gives the room back as you scroll up and can't be stretched by overscrolling", token: "ExplorerTreeHold.spacerHeight")),
            ], rounds: ["decided.rail-servers", r19Switching], files: [components + "ExplorerTreeLayout.swift", components + "ExplorerTreeScrollState.swift"]),
        ]),
        SpecPart(number: "2", name: "Header", summary: "The server's name and version at the top of its card.", elements: [
            SpecElement(number: "2.1", name: "Server name", summary: "Bold, at the top left of the card, sized by the sidebar size.", groups: [
                .type(.row("Font", "bold; compact 11 · small 10 · medium 13 · large 14pt", token: "serverNameFont / SidebarRowConstants.serverHeaderFont"),
                      .row("Colour", "primary"), .row("Lines", "1")),
                .layout(.row("Padding", "12pt leading and top", token: "SpacingTokens.sm"), .row("Trailing", "8pt + 6pt")),
                .states(.row("Connecting or testing", "a mini spinner at the trailing edge")),
            ], files: ["Echo/Sources/Features/ObjectBrowser/Views/Components/ObjectBrowserRowView+Headers.swift"]),
            SpecElement(number: "2.2", name: "Product line", summary: "The product and release under the name, then the dock's current section (round 19).", groups: [
                .type(.row("Font", "detail 11pt, monospaced digits", token: "SidebarRowConstants.trailingFont"), .row("Colour", "tertiary"), .row("Lines", "1")),
                .layout(.row("Gap to the name", "1pt", token: "SpacingTokens.micro")),
                .behaviour(.row("Text", "product and release, then · and the current section: SQL Server 2022 · Security", token: "ServerProductLabel.label / productLine"),
                           .row("Tooltip", "the full build")),
            ], rounds: [round16], files: ["Echo/Sources/Features/ObjectBrowser/Views/Components/ObjectBrowserRowView+Headers.swift"]),
            SpecElement(number: "2.3", name: "Pinned header", summary: "The name and dock stay at the top while rows scroll under them.", groups: [
                .material(.row("At rest", "nothing behind it"),
                          .row("Once rows scroll under it", "a wash of the card colour: 85% at the top, 45% at 55%, clear at the bottom", token: "ExplorerPinnedHeaderWash"),
                          .row("Rows", "blur and fade as they pass under it", token: "ExplorerRowEdgeBlur")),
                .motion(.row("Wash in", "ease out, 0.12s")),
                .behaviour(.row("No line and no grey material", "the soft blur is the only edge")),
            ], rounds: ["decided.tree-sticky-header", round16], files: [components + "ExplorerPinnedHeaderWash.swift"]),
        ]),
        SpecPart(number: "3", name: "Dock", summary: "The section icons under the server's name.", elements: [
            SpecElement(number: "3.1", name: "Capsule", summary: "A Liquid Glass capsule as wide as the card, with a hairline edge and a soft shadow (C5). The only glass in the card.", groups: [
                .material(.row("Glass", "Liquid Glass, regular, capsule"),
                          .row("Edge", "the card edge's colour at 80%, 0.5pt", token: "LayoutTokens.ExplorerDock.edgeOpacity"),
                          .row("Shadow", "black 8%, radius 4, y 1", token: "LayoutTokens.ExplorerDock.shadowOpacity")),
                .layout(.row("Height", "compact 22 · small 24 · medium 28 · large 32pt", token: "LayoutTokens.ExplorerDock.capsuleHeight(for:)"),
                        .row("Inner padding", "6pt horizontal", token: "SpacingTokens.xxs2"),
                        .row("Outer padding", "6pt", token: "SidebarRowConstants.rowOuterHorizontalPadding"),
                        .row("Row slot", "an ordinary row plus 8pt", token: "LayoutTokens.ExplorerDock.extraHeight")),
            ], rounds: [round16, round14, r19Capsule], files: [components + "ExplorerDockRow.swift"]),
            SpecElement(number: "3.2", name: "Current section icon", summary: "The section shown, in the accent colour. It has no fill.", groups: [
                .type(.row("Symbol", "medium weight; 14pt at the default size (compact 11, small 10, large: display medium)", token: "ExplorerDockRow.iconFont")),
                .states(.row("Colour", "accent", token: "ColorTokens.accent"), .row("Fill", "none")),
                .layout(.row("Slot", "equal share of the capsule, as tall as the capsule"), .row("Hit area", "the whole slot")),
            ], rounds: [round16], files: [components + "ExplorerDockRow.swift"]),
            SpecElement(number: "3.3", name: "Other section icons", summary: "Duotone in the tree's colours; grey when the icon setting is mono.", groups: [
                .material(.row("Duotone", "outline in the role colour over its fill variant at 22%", token: "SidebarDuotoneSymbols.fillOpacity"),
                          .row("Mono", "grey", token: "ColorTokens.Sidebar.symbol")),
                .behaviour(.row("Tooltip", "Title · count")),
                .motion(.row("Hover", "an icon that isn't the current one grows 12%", token: "LayoutTokens.ExplorerDock.hoverScale / echoMotion.hover")),
            ], rounds: ["ported.Round 14 · section dock", r19Capsule], files: [components + "ExplorerDockRow.swift"]),
            SpecElement(number: "3.4", name: "More", summary: "Sections left out of the capsule are the » section, listed as ordinary folders (round 19).", groups: [
                .type(.row("Glyph", "chevron.right.2 at the dock icon size and weight")),
                .states(.row("More is showing", "accent"), .row("Otherwise", "secondary")),
                .behaviour(.row("Click", "shows the left-out sections as folders you can open and right-click, like any other section"), .row("Tooltip", "More sections"),
                           .row("Shown", "only when a section is left out")),
            ], rounds: [round16, r19Sections], files: [components + "ExplorerDockRow.swift"]),
            SpecElement(number: "3.5", name: "Which sections show", summary: "The server's own choice, then its type's setting, then the blueprint's; at most five.", groups: [
                .behaviour(.row("Order", "saved order wins, then the blueprint's; keys neither names go under More"),
                           .row("Capsule limit", "five sections; the rest go under More", token: "ExplorerDock.capsuleLimit"),
                           .row("Never empty", "if nothing matches, all sections show"),
                           .row("No dock", "a server with fewer than two sections, or sections the dock can't describe, keeps its plain tree")),
            ], rounds: [round16, r19Sections], files: [components + "ExplorerDock.swift", "Echo/Sources/Features/ObjectBrowser/Blueprint/"]),
            SpecElement(number: "3.6", name: "Dock menus", summary: "Right-click the dock.", groups: [
                .behaviour(.row("On an icon", "that section's menu and Dock"), .row("On the empty capsule", "Dock alone"),
                           .row("Dock", "opens the customising sheet (order, which sections show, per server or per type)")),
            ], rounds: [round16], files: [components + "ExplorerDockCustomizationSheet.swift"]),
            SpecElement(number: "3.7", name: "Switching sections", summary: "The rows fade out, swap and fade in while the card's edge settles (S3).", groups: [
                .motion(.row("Fade out", "ease in, 0.08s", token: "ObjectBrowserSidebarView.dockFadeOutDuration"),
                        .row("Fade in", "ease out, 0.18s", token: "dockFadeInDuration"),
                        .row("Scaled by", "the Motion speed setting", token: "motion.durationScale"),
                        .row("Card edge", "settles as the section changes, without overshoot")),
                .behaviour(.row("Position", "each section keeps its scroll position and open folders; the view jumps, unanimated, to where the section was left"),
                           .row("A section not shown before", "doesn't scroll"), .row("While fading", "another click is ignored")),
            ], rounds: ["ported.Round 14 · section dock", round16, r19Switching], files: [components + "ObjectBrowserSidebarView+Dock.swift", "Echo/Sources/Features/ObjectBrowser/Views/Components/ObjectBrowserSidebarViewModel+Dock.swift"]),
            SpecElement(number: "3.8", name: "SQL Server's five sections", summary: "Grouped as SSMS groups them (round 19).", groups: [
                .behaviour(.row("Databases", "the databases, with Database Snapshots at the end"), .row("Security", "Logins, Server Roles, Credentials"),
                           .row("Server Objects", "Linked Servers, Server Triggers"), .row("Agent Jobs", "Job Queue and the jobs"),
                           .row("Management", "Extended Events, Database Mail, SQL Profiler, Resource Governor, Tuning Advisor, Policy Management, Activity Monitor, SQL Server Logs, Integration Services"),
                           .row("Other engines", "no blueprint has more than five sections")),
            ], rounds: [r19Sections], files: ["Echo/Sources/Features/ObjectBrowser/Blueprint/ExplorerBlueprint+SQLServer.swift"]),
        ]),
        SpecPart(number: "4", name: "Rows", summary: "Quiet rows: one icon slot, one label, an optional count.", elements: [
            SpecElement(number: "4.1", name: "Row", summary: "The shape every row shares (S4 Quiet).", groups: [
                .layout(.row("Height", "28pt in a 29pt slot at the default density; vertical padding 3 · 4 · 6 · 7 by density", token: "SidebarRow.densityVerticalPadding"),
                        .row("Indent", "16pt per level, outside the highlight", token: "SidebarRowConstants.indentStep"),
                        .row("Padding", "6pt leading · 8pt trailing inside; 6pt outside", token: "rowLeadingPadding / rowTrailingPadding / rowOuterHorizontalPadding"),
                        .row("Icon to label", "8pt", token: "SidebarRowConstants.iconTextSpacing"),
                        .row("Highlight corner", "8pt continuous", token: "LayoutTokens.Workspace.treeRowCornerRadius")),
                .behaviour(.row("Density", "the Sidebar Size setting scales the label and the vertical padding")),
            ], rounds: ["decided.tree-card-s4-quiet"], files: [rows, constants]),
            SpecElement(number: "4.2", name: "Icon", summary: "One slot for a row's symbol.", groups: [
                .layout(.row("Frame", "18 × 16pt", token: "SidebarRowConstants.iconFrameWidth / Height")),
                .type(.row("Symbol", "regular 14pt", token: "SidebarRowConstants.iconFont")),
                .material(.row("Duotone (default)", "outline in the role colour over its fill at 22%", token: "IC2"),
                          .row("Mono line (setting)", "grey", token: "IC1")),
                .states(.row("Selected", "accent")),
            ], rounds: ["ported.Round 14 · section dock"], files: [rows]),
            SpecElement(number: "4.3", name: "Label", summary: "One line; a schema prefix is dimmed.", groups: [
                .type(.row("Font", "13pt at the default density; scales with the size setting", token: "densityLabelFont"),
                      .row("Colour", "primary"), .row("Lines", "1, truncated at the end"),
                      .row("Schema prefix", "\"HumanResources.\" in tertiary on tables outside the default schema")),
            ], files: [rows]),
            SpecElement(number: "4.4", name: "Folder row", summary: "The folder's icon becomes a chevron under the pointer.", states: [SpecState(key: "hoverRow", name: "Hovered")], defaultState: "hoverRow", groups: [
                .type(.row("Chevron", "semibold 11pt, tertiary", token: "SidebarRowConstants.chevronFont")),
                .motion(.row("Open and close", "ease in-out, 0.22s; rows below slide and fade", token: "echoMotion.expand"),
                        .row("Chevron", "turns 90° when open")),
                .behaviour(.row("Click", "opens or closes the folder; nothing else moves")),
            ], rounds: ["decided.tree-card-s4-quiet"], files: [rows]),
            SpecElement(number: "4.5", name: "Count", summary: "How many items a folder holds. Always shown, quietly.", groups: [
                .type(.row("Font", "detail 11pt, monospaced digits", token: "SidebarRowConstants.trailingFont"), .row("Colour", "quaternary")),
                .behaviour(.row("Shown", "always, when above zero"), .row("Why always", "a count that appeared on hover blinked whenever the row was rebuilt under the pointer"),
                           .row("Accessibility", "\"N items\"")),
            ], rounds: [round16], files: [rows]),
            SpecElement(number: "4.6", name: "Hover", summary: "A soft fill under the pointer.", states: [SpecState(key: "hoverObject", name: "Hovered")], defaultState: "hoverObject", groups: [
                .material(.row("Fill", "hover fill", token: "ColorTokens.Sidebar.hoverFill", swatch: ColorTokens.Sidebar.hoverFill)),
                .motion(.row("Fade", "ease out, 0.12s", token: "echoMotion.hover"), .row("Moves", "nothing: only the fill animates")),
            ], files: [rows]),
            SpecElement(number: "4.7", name: "Selected", summary: "A grey fill with the icon in its accent.", groups: [
                .material(.row("Fill", "selected fill", token: "ColorTokens.Sidebar.selectedFill", swatch: ColorTokens.Sidebar.selectedFill)),
                .states(.row("Icon", "accent")),
                .motion(.row("Fade", "ease out, 0.16s")),
                .layout(.row("Width", "from the icon to the trailing edge; not the indent")),
            ], rounds: ["decided.tree-card-s4-quiet"], files: [rows]),
            SpecElement(number: "4.8", name: "Row under a context menu", summary: "The row a right-click menu is open for keeps a fill.", groups: [
                .material(.row("Fill", "context fill", token: "ColorTokens.Sidebar.contextFill")),
            ], files: [rows]),
            SpecElement(number: "4.9", name: "Subtitle", summary: "An optional second line under the label.", groups: [
                .type(.row("Font", "detail 11pt", token: "SidebarRowConstants.trailingFont"), .row("Colour", "tertiary"), .row("Lines", "1")),
            ], files: [rows]),
            SpecElement(number: "4.10", name: "Context menu", summary: "Right-click a row.", groups: [
                .behaviour(.row("Items", "for that node kind, from the database type's blueprint"),
                           .row("Reveal in the tree", "smooth scroll, 0.40s", token: "echoMotion.reveal")),
            ], files: ["Echo/Sources/Features/ObjectBrowser/Views/Components/ObjectBrowserSidebarView+ContextMenus.swift"]),
        ]),
        SpecPart(number: "5", name: "Not built", summary: "Things that were tried or planned and are not in Echo.", elements: [
            SpecElement(number: "5.1", name: "Pinned path header", summary: "A sticky header that showed the path to the row at the top. Removed; the dock orients instead.", isRetired: true),
            SpecElement(number: "5.2", name: "Recraft icon set", summary: "Planned; SF Symbols drawn duotone until then.", isRetired: true),
        ]),
    ]
}
