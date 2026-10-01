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
    private static let r30Collapse = "ongoing.server-header-collapse-r30"

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
            ], rounds: ["decided.window-canvas-and-cards"], files: ["Packages/EchoDesignSystem/Sources/EchoDesignSystem/Explorer/ExplorerTreeCardsLayer.swift"]),
            SpecElement(number: "1.2", name: "One card per server", summary: "Servers are never merged into one list; a server's card is as tall as its rows.", groups: [
                .behaviour(.row("Rail", "Clicking a server in the rail jumps to its card; the rail marks the card at the top while you scroll"),
                           .row("Holding view (N2)", "when a card gets shorter, a spacer under the last card keeps the bottom where it was, so the cards above don't move; it gives the room back as you scroll up and can't be stretched by overscrolling", token: "ExplorerTreeHold.spacerHeight"),
                           .row("Row slot", "each row sits in a slot exactly its kind's height, sized without asking the row, so scrolling never measures rows again", token: "ExplorerTreeRowSlot")),
            ], rounds: ["decided.rail-servers", r19Switching], files: ["Packages/EchoDesignSystem/Sources/EchoDesignSystem/Explorer/ExplorerTreeLayout.swift", "Packages/EchoDesignSystem/Sources/EchoDesignSystem/Explorer/ExplorerTreeRowSlot.swift","Packages/EchoDesignSystem/Sources/EchoDesignSystem/Explorer/ExplorerTreeScrollState.swift", components + "ObjectBrowserNode+TreeRole.swift"]),
        ]),
        SpecPart(number: "2", name: "Header", summary: "The server's name and version at the top of its card.", elements: [
            SpecElement(number: "2.1", name: "Server name", summary: "Bold, at the top left of the card, sized by the sidebar size.", groups: [
                .type(.row("Font", "bold; compact 11 · small 10 · medium 13 · large 14pt", token: "serverNameFont / SidebarRowConstants.serverHeaderFont"),
                      .row("Colour", "primary"), .row("Lines", "1")),
                .layout(.row("Padding", "12pt leading; 12pt top while open, centred in the card while closed (round 30.2)", token: "SpacingTokens.sm / treeCardBottomPadding"), .row("Trailing", "8pt + 6pt")),
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
            ], rounds: ["decided.tree-sticky-header", round16], files: ["Packages/EchoDesignSystem/Sources/EchoDesignSystem/Explorer/ExplorerPinnedHeaderWash.swift"]),
            SpecElement(number: "2.4", name: "Collapse chevron", summary: "At the trailing edge, centred on the name and product line (CP1); › turning down when open (CS0).", groups: [
                .type(.row("Chevron", "semibold 11pt, tertiary", token: "SidebarRowConstants.sectionChevronFont")),
                .layout(.row("Place", "trailing, centred on the two lines, open or closed", token: "HStack(alignment: .center)")),
                .behaviour(.row("Shows", "on hover while open, always while closed (CV0)"), .row("Turns", "90° when open")),
                .motion(.row("Turn", "ease in-out, 0.22s", token: "echoMotion.expand"), .row("Show and hide", "ease in-out, 0.15s")),
            ], rounds: [r30Collapse], files: [components + "ObjectBrowserRowView+Headers.swift"]),
            SpecElement(number: "2.5", name: "Folding the card", summary: "Click the header: the card folds to its header while the rows fade (CM2), and opens the same way.", groups: [
                .layout(.row("Closed card", "the header only (CC0): the slot plus 4pt, the name, product line and chevron centred in it")),
                .motion(.row("Card edge", "ease in-out, 0.22s", token: "echoMotion.expand / ExplorerTreeCardsLayer.foldingCardIDs"),
                        .row("Rows and dock", "fade over the same 0.22s and are cut by the moving edge and its corners, so none shows outside the card", token: "ExplorerTreeFoldTransition"),
                        .row("Header", "glides between its open place (12pt down) and the centre of the closed card")),
                .behaviour(.row("Two steps", "the cards are marked as folding first, then the server opens or closes, so leaving rows carry the fold", token: "ObjectBrowserSidebarView.foldServerCard"),
                           .row("The cards below", "move with the edge, on the same curve")),
            ], rounds: [r30Collapse], files: [components + "ObjectBrowserSidebarView+Fold.swift", components + "ObjectBrowserOutlineView+Fold.swift",
                                              "Packages/EchoDesignSystem/Sources/EchoDesignSystem/Explorer/ExplorerTreeFoldTransition.swift"]),
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
            SpecElement(number: "3.3", name: "Other section icons", summary: "Grey by default; duotone in the tree's colours is a setting (Dock icons).", groups: [
                .material(.row("Mono (default)", "grey", token: "ColorTokens.Sidebar.symbol"),
                          .row("Duotone (setting)", "outline in the role colour over its fill variant at 22%", token: "SidebarDuotoneSymbols.fillOpacity"),
                          .row("Setting", "Settings › Appearance › Dock icons", token: "SidebarDockIconStyle")),
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
                           .row("Dock", "opens the Customize Dock sheet"),
                           .row("The sheet", "titled Customize Dock with the server's name; Applies to every server of its type or this server only; the sections as toggles you drag to reorder (at most five show, the rest are under More); Icons for the dock (Mono or Duotone) and the tree (Colourful or Monochrome); Use Default Sections; Done, disabled while no section is on")),
            ], rounds: [round16], files: [components + "ExplorerDockCustomizationSheet.swift"]),
            SpecElement(number: "3.7", name: "Switching sections", summary: "A veil in the card's colour fades over the rows, the section swaps and the card's edge moves under it, then the veil fades away (S3).", groups: [
                .motion(.row("Veil in", "ease out, 0.12s", token: "ExplorerDockSwitchTiming.fadeOutDuration"),
                        .row("Card edge", "smooth, no overshoot, 0.28s; only the switching card animates", token: "EchoMotion.dockEdge"),
                        .row("Veil out", "ease out, 0.22s", token: "ExplorerDockSwitchTiming.fadeInDuration"),
                        .row("Scaled by", "the Motion speed setting", token: "motion.durationScale")),
                .behaviour(.row("Position", "each section keeps its scroll position and open folders; the view jumps, unanimated, to where the section was left"),
                           .row("A section not shown before", "doesn't scroll"), .row("While switching", "another click on that server's dock is ignored"),
                           .row("The section", "opens (and starts loading) when the switch starts, under the fading veil"),
                           .row("The window", "can't be dragged while the switch runs", token: "WindowDragPause")),
            ], rounds: ["ported.Round 14 · section dock", round16, r19Switching], files: [components + "ObjectBrowserSidebarView+Dock.swift", "Packages/EchoDesignSystem/Sources/EchoDesignSystem/Explorer/ExplorerMotion.swift", "Packages/EchoDesignSystem/Sources/EchoDesignSystem/Explorer/ExplorerTreeVeilLayer.swift", "Echo/Sources/Features/ObjectBrowser/Views/Components/ObjectBrowserSidebarViewModel+Dock.swift"]),
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
                        .row("Densities", "Compact, Small, Default (medium), Large: the Sidebar Size setting", token: "SidebarDensity"),
                        .row("Indent", "16pt per level, outside the highlight", token: "SidebarRowConstants.indentStep"),
                        .row("Padding", "6pt leading · 8pt trailing inside; 6pt outside", token: "rowLeadingPadding / rowTrailingPadding / rowOuterHorizontalPadding"),
                        .row("Icon to label", "8pt", token: "SidebarRowConstants.iconTextSpacing"),
                        .row("Highlight corner", "8pt continuous", token: "LayoutTokens.Workspace.treeRowCornerRadius")),
                .behaviour(.row("Density", "the Sidebar Size setting scales the label and the vertical padding")),
            ], rounds: ["decided.tree-card-s4-quiet"], files: [rows, constants]),
            SpecElement(number: "4.2", name: "Icon", summary: "One slot for a row's symbol.", groups: [
                .layout(.row("Frame", "18 × 16pt at the default size (compact 14 × 12, small 16 × 14, large 20 × 18)", token: "SidebarRow.densityIconFrameWidth / Height"),
                        .row("Scale", "medium")),
                .type(.row("Symbol", "light weight: 13pt at the default size (compact 10, small 11, large 14)", token: "SidebarRow.densityIconFont")),
                .material(.row("Colourful (default)", "outline in the role colour softened 22% towards secondary, over its fill variant at 22%, where the symbol has one", token: "ColorTokens.Explorer.colorfulSoftening / SidebarDuotoneSymbols.fillOpacity"),
                          .row("Monochrome (setting)", "secondary grey; a folder that is open takes the accent colour with Accent on open, the default", token: "SidebarIconColorMode / SidebarMonochromeVariant"),
                          .row("Objects", "tables, views and the like are always the grey symbol colour", token: "ColorTokens.Sidebar.symbol")),
                .states(.row("Selected", "accent")),
            ], rounds: ["ported.Round 14 · section dock"], files: [rows]),
            SpecElement(number: "4.3", name: "Label", summary: "One line; a schema prefix is dimmed.", groups: [
                .type(.row("Font", "13pt at the default density (compact 10, small 11, large 15)", token: "SidebarRow.densityLabelFont"),
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
        SpecPart(number: "6", name: "Row kinds and loading", summary: "The other rows a card holds, and how a loading section looks.", elements: [
            SpecElement(number: "6.1", name: "Database row", summary: "A cylinder, the name, and its state.", groups: [
                .behaviour(.row("Offline or no access", "the row is at 50%; the state (OFFLINE and so on) or NO ACCESS shows in 9pt uppercase quaternary at the right"),
                           .row("No access", "the label is secondary"), .row("Loading", "a mini spinner at the right")),
            ], files: [components + "ObjectBrowserRowView+Components.swift"]),
            SpecElement(number: "6.2", name: "Empty object folder", summary: "Tables, Views, Functions and Procedures always show, empty or not (EF1, round 30.3); the rarer folders only when they have something. An empty one steps back (EL1).", groups: [
                .states(.row("Icon", "quaternary"), .row("Label", "tertiary"), .row("Count", "none")),
                .behaviour(.row("Always shown", "Tables, Views, Functions, Procedures", token: "ExplorerBlueprintWalker.alwaysShownObjectTypes"),
                           .row("Opening it", "it opens like any folder, to a grey “No views” row (OE0)", token: "ExplorerBlueprintWalker.emptyFolderRow"),
                           .row("Setting", "none: Show Empty Folders was removed (ST1)")),
            ], rounds: ["ongoing.empty-folders-r30"], files: [components + "ObjectBrowserRowView+Components.swift", "Echo/Sources/Features/ObjectBrowser/Blueprint/ExplorerBlueprintWalker.swift"]),
            SpecElement(number: "6.3", name: "Item and tool rows", summary: "A loaded item, or a tool the folder offers.", groups: [
                .material(.row("Item icon", "secondary; quaternary when disabled"), .row("Item label", "primary; secondary when disabled"),
                          .row("Tool icon", "its role colour, like a folder's")),
                .type(.row("Detail", "11pt tertiary at the right, when the item has one")),
            ], files: [components + "ObjectBrowserRowView+Components.swift"]),
            SpecElement(number: "6.4", name: "Column rows", summary: "Under a table.", groups: [
                .material(.row("Primary key", "a filled key in orange"), .row("Foreign key", "an arrow.turn.down.right in the info colour", token: "ColorTokens.Status.info"),
                          .row("Other columns", "no icon")),
                .type(.row("Type", "11pt tertiary at the right, abbreviated", token: "EchoFormatters.abbreviatedSQLType")),
            ], files: [components + "ObjectBrowserRowView+Components.swift"]),
            SpecElement(number: "6.5", name: "Loading a section", summary: "While a section's source loads.", groups: [
                .behaviour(.row("Folders", "a mini spinner in the count's place"), .row("Item-only level", "one spinner row, such as Loading databases"),
                           .row("Skeleton rows", "three placeholder rows at the child indent; the real rows fade in over them", token: "LayoutTokens.Shimmer.explorerRowCount")),
            ], rounds: [round16], files: [components + "ObjectBrowserRowView.swift"]),
            SpecElement(number: "6.6", name: "Selected server pulse", summary: "A wave of the success colour across the server's header when it is revealed.", groups: [
                .material(.row("Colour", "success", token: "ColorTokens.Status.success"), .row("Corner", "8pt", token: "SidebarRowConstants.hoverCornerRadius")),
            ], files: [components + "ObjectBrowserRowView+Components.swift"]),
        ]),
        SpecPart(number: "5", name: "Not built", summary: "Things that were tried or planned and are not in Echo.", elements: [
            SpecElement(number: "5.1", name: "Pinned path header", summary: "A sticky header that showed the path to the row at the top. Removed; the dock orients instead.", isRetired: true),
            SpecElement(number: "5.2", name: "Recraft icon set", summary: "Planned; SF Symbols drawn duotone until then.", isRetired: true),
        ]),
    ]
}
