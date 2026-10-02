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
                           .row("Holding view (N2)", "when a card gets shorter, a spacer under the last card keeps the bottom where it was, so the cards above don't move; it is worked out in the same layout pass as the shorter rows (from the last metrics the scroll view reported), so the view is never clamped for a frame and a card never jumps when you pick another dock icon; it gives the room back as you scroll up and can't be stretched by overscrolling, and a card closing or a server arriving still leaves it to the scroll position (2026-10-02). A fold that leaves the tree shorter than the view glides back with it instead (2026-10-02)", token: "ExplorerTreeScrollState.holdHeight"),
                           .row("Row slot", "each row sits in a slot exactly its kind's height, sized without asking the row, so scrolling never measures rows again", token: "ExplorerTreeRowSlot"),
                           .row("Placed, not stacked", "rows sit at their exact layout places (no estimated heights), built only near the view: the view and an eighth of a view each side (2026-10-02)", token: "ExplorerTreeCanvasLayout / ExplorerTreeWindow")),
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
                .motion(.row("Wash in", "follows the scroll: full once rows have passed 12pt under the header (2026-10-02; was ease out 0.12s)", token: "ExplorerPinnedHeaderWash.fadeDistance"),
                        .row("Pinning", "a visual effect from where the scroll view has the header, so a scrolled frame runs no bodies", token: "ExplorerTreePinnedHeader")),
                .behaviour(.row("No line and no grey material", "the soft blur is the only edge")),
            ], rounds: ["decided.tree-sticky-header", round16], files: ["Packages/EchoDesignSystem/Sources/EchoDesignSystem/Explorer/ExplorerPinnedHeaderWash.swift"]),
            SpecElement(number: "2.4", name: "Collapse chevron", summary: "At the trailing edge, centred on the name and product line (CP1); › turning down when open (CS0).", groups: [
                .type(.row("Chevron", "semibold 11pt, tertiary", token: "SidebarRowConstants.sectionChevronFont")),
                .layout(.row("Place", "trailing, centred on the two lines, open or closed", token: "HStack(alignment: .center)")),
                .behaviour(.row("Shows", "on hover while open (CV0; a closed card is no longer drawn, round 51)"), .row("Turns", "90° when open")),
                .motion(.row("Turn", "the house spring, a little bounce (round 53, CH1 and MO0); a short fade with Reduce Motion", token: "echoMotion.standard"), .row("Show and hide", "ease in-out, 0.15s")),
                .material(.row("Colour", "tertiary on the card; the type's colour at 90% on the title banner, white on the old banner")),
            ], rounds: [r30Collapse, "ongoing.server-header-custom-r53", "ongoing.header-sizes-r58"], files: [components + "ObjectBrowserRowView+Headers.swift"]),
            SpecElement(number: "2.5", name: "Folding the card", summary: "Click the header: the card opens with its dock growing out of the header and its rows under the section switch's veil, and closes by covering the rows, then folding; a closed (minimized) card then leaves the list (rounds 30.2, 46 and 51).", groups: [
                .layout(.row("Minimized card (round 51, SH5)", "not in the list at all, replacing the header-only closed card of CC0: the cards below close the gap, and the server stays in the rail below the hairline, unmarked (WIN-2.2, round 55); the card leaves with opacity and a 97% scale from its top. Every card minimized: the tree says All Servers Are Minimized", token: "ObjectBrowserSnapshotBuilder.buildRoots / ExplorerMinimizedServers")),
                .motion(.row("Card edge", "ease in-out, 0.22s", token: "echoMotion.expand / ExplorerTreeCardsLayer.foldingCardIDs"),
                        .row("Dock (DA2)", "grows from 92% and 3pt out of focus to full size, anchored at its top, cut by the moving edge; it never fades, so its glass blurs from the first frame", token: "ExplorerTreeFoldTransition.Style.grow"),
                        .row("Rows, opening (RA1)", "hidden under an opaque veil in the card's colour that grows with the edge; when the edge settles they show and the veil fades away, ease out 0.22s", token: "ExplorerDockSwitchTiming.fadeIn"),
                        .row("Rows, closing (CL2)", "the veil fades over them, ease out 0.12s; then they go at once under it and the edge closes as the dock shrinks back", token: "ExplorerDockSwitchTiming.fadeOut"),
                        .row("Leaving and arriving card", "its header and card background fade as the card leaves or returns, while the cards below slide on the list's curve (round 54 will replace this with the card travelling to the trail)", token: "ExplorerTreeCardsLayer / ObjectBrowserOutlineView+Rows"),
                        .row("Header", "the title banner; it stays at its open place until the card leaves")),
                .behaviour(.row("Two steps", "this card is marked as folding first, then the server opens or closes, so leaving rows carry the fold; cards open and close independently (no one-at-a-time setting since round 51)", token: "ObjectBrowserSidebarView.foldServerCard"),
                           .row("Restoring (round 51, SH5)", "a minimized server in the rail (below the hairline), or anything that reveals it, opens the card again in the list and selects it; the open folders load again", token: "ObjectBrowserSidebarView.revealConnection / applyMinimizedServers"),
                           .row("Kept", "minimized is the server's absence from the expanded set, kept between launches with the rest of the tree's open state", token: "ObjectBrowserSidebarViewModel+Persistence"),
                           .row("The cards below", "move with the edge, on the same curve"),
                           .row("Animation", "a fold keeps the list's animation: only a section switch turns it off", token: "ObjectBrowserOutlineView.dockSwitchKey")),
            ], rounds: [r30Collapse, "ongoing.server-card-unfold-r46"], files: [components + "ObjectBrowserSidebarView+Fold.swift", components + "ObjectBrowserOutlineView+Fold.swift",
                                              "Packages/EchoDesignSystem/Sources/EchoDesignSystem/Explorer/ExplorerTreeFoldTransition.swift"]),
            SpecElement(number: "2.6", name: "Header colour", summary: "Settings › Appearance › Server Header and Server Header Color (round 30.1): the title banner by default since round 53 (2.7); the wash and four others stay.", groups: [
                .material(.row("Wash (HD4, default until round 53)", "the colour at 20% at the card's top edge, fading to clear through the dock (8% grey with None); the whole card when closed", token: "ServerHeaderBackdrop"),
                          .row("Plain (HD0)", "the name and product line alone"),
                          .row("Bar (HD12)", "a 3pt rounded bar of the colour in the leading padding, beside the two lines"),
                          .row("Glass Plate (HD7)", "the name on a glass capsule tinted 28% with the colour"),
                          .row("Banner (HD16)", "the colour at 95%, 80% halfway, clear by the dock's bottom; white name, product line and chevron; a closed card is all banner")),
                .layout(.row("Reach", "the header slot and the dock slot while open, the closed card while closed, 0.5pt inside the card's edge, its top corners the card's", token: "ObjectBrowserRowView.serverBackdropHeight")),
                .behaviour(.row("Colour", "the server's colour by default; the accent, or none, in Settings", token: "ServerHeaderColorSource"),
                           .row("Server's colour elsewhere", "with the server's colour: the rail's monogram always (WIN-2.3); the dots on tabs and the footer's pill went in round 49", token: "ServerHeaderPaint.marksServer"),
                           .row("Setting it", "the header's right-click menu › Color lists the thirty colours (2.8); it saves the connection's colour and shows at once", token: "ObjectBrowserSidebarView.addServerColorMenu")),
            ], rounds: ["ongoing.server-header-look-r30"], files: ["Echo/Sources/Features/ObjectBrowser/Domain/ServerHeaderPaint.swift", components + "ServerHeaderBackdrop.swift",
                                                                    components + "ObjectBrowserRowView+ServerHeader.swift", components + "ObjectBrowserSidebarView+ServerColor.swift"]),
            SpecElement(number: "2.7", name: "Title banner", summary: "The default header (round 53, F5): the server's colour in full, a line of small capitals over a large name, the dock's icons straight on the colour.", groups: [
                .material(.row("Fill", "the colour at 92% to 100% top to bottom, through the dock while open; the whole card when closed, its corners the card's", token: "ServerTitleBannerFill / ServerHeaderTokens.bannerTopOpacity"),
                          .row("Edge (ED1, default)", "0.5pt of white at 35% along the bottom, open cards only; Sharp, Soft Fade (clear from 62%) and Frosted Fade (80% then a 36pt band of material) are the others", token: "ServerHeaderEdge"),
                          .row("Type colour", "white; Automatic turns it to 82% black above a luminance of 0.62 (Rec. 709, in the current appearance)", token: "ServerHeaderContrast.darkTypeThreshold")),
                .type(.row("Line above the name", "10pt bold, tracked 1.1, type colour at 82%, capitals (round 58); the section (default), the engine (SQL SERVER, POSTGRESQL, MYSQL, SQLITE, no version), or both, over the name; Section at the Right puts the section on the name's row at its right end, left of the chevron's reserved slot, taking at most 40% of the row while the name truncates, so it never meets the chevron; Nothing Above the Name draws no line and no product line, the header is the name and the space and 15pt shorter (a card with no dock shows the engine instead of a section)", token: "ServerHeaderTokens.eyebrowFont / ServerHeaderEyebrow"),
                      .row("Name", "semibold, Tiny 12, Extra Small 14, Small 16, Standard 18 (default), Large 22 or Extra Large 26pt (round 58), in System, Rounded, Serif, Monospaced or Expanded", token: "ServerHeaderTokens.nameFont")),
                .layout(.row("Slot", "from the card's top: the space (Tight 6pt, the default; Standard 10pt), the line over the name (10pt type in a 12pt line) and a 3pt gap when there is one, the name's line (size x 1.2, rounded: 14, 17, 19, 22, 26 or 31pt), then nothing (Tight) or 4pt (Standard) before the dock; the section at the right shares the name's row and adds no height. At the default (18pt, the section, Tight) the header is 43pt and, with the dock's 37pt slot, the banner is 80pt tall at the default sidebar size; Nothing Above the Name is 28pt (65pt with the dock), Standard is 8pt more. The same number sizes the server row in the tree layout, the banner's backdrop and the drawing, which fixes each line to its height, so there is never a gap, an overlap or a clipped line; the dock capsule is centred in its slot, 4.5pt under the name; all server headers share it", token: "ServerHeaderMetrics.headerHeight / ObjectBrowserNode.Row.serverHeaderHeight")),
                .states(.row("Dock icons", "no capsule, pill or underline; the current one is the filled symbol, bold, 15pt at the default size, in full type colour; the others medium at 72%; same slots, menus and More (»)", token: "ExplorerBannerDockRow")),
                .behaviour(.row("Customising", "Settings › Appearance › Server Header: Server Name Typeface, Server Name Size, Line Above the Name, Spacing (Tight or Standard, round 58), Banner Edge, Banner Text Color, one setting for every card (LV2, SC0); weight, alignment, fill and icon size are not offered, and there are no rounded corners", token: "ServerHeaderLook / ServerHeaderLookRows"),
                           .row("Settings from before round 53", "a saved Wash moves to this default once; every other saved style stays", token: "GlobalSettings.decodedServerHeaderStyle"),
                           .row("Settings from before round 58", "saved Small, Medium and Large still mean 18, 22 and 26pt; a look saved without Spacing whose size is Medium and whose line is the section was never chosen, so it moves once to 18pt, the section and Tight; any other saved choice stays", token: "ServerHeaderLook.migratedNameSize")),
            ], rounds: ["ongoing.server-header-polish-r50", "ongoing.server-header-custom-r53", "ongoing.header-sizes-r58"], files: ["Echo/Sources/Features/ObjectBrowser/Domain/ServerHeaderTokens.swift", "Echo/Sources/Features/ObjectBrowser/Domain/ServerHeaderTitle.swift",
                                                                     "Echo/Sources/Features/Preferences/Domain/ServerHeaderLook.swift", components + "ServerTitleBannerFill.swift", components + "ExplorerBannerDockRow.swift",
                                                                     components + "ObjectBrowserRowView+ServerHeader.swift"]),
            SpecElement(number: "2.8", name: "Server colours", summary: "Thirty colours with a light and a dark variant, and a colour well for any other (round 50, PC3).", groups: [
                .material(.row("Palette", "Crimson to Navy: each colour has a light and a dark value, so it holds in both appearances", token: "ServerColorPalette.all"),
                          .row("Storage", "a palette colour is saved as its light hex, the string a connection already stores; its dark twin is found by that hex, so sync and old data are unchanged", token: "SavedConnection.colorHex")),
                .behaviour(.row("Any other colour", "a colour from the well, or one of the five earlier colours, draws as saved in both appearances", token: "ServerColorPalette.swiftUIColor"),
                           .row("Where", "the Customize Appearance popover and the connection sheet (swatches and the well), and the header's right-click menu (swatches)", token: "ServerColorSwatches"),
                           .row("New server", "starts as Azure", token: "ServerColorPalette.defaultColor")),
            ], rounds: ["ongoing.server-header-polish-r50"], files: ["Echo/Sources/Shared/DesignSystem/ServerColorPalette.swift", "Echo/Sources/Shared/DesignSystem/ServerColorPalette+Color.swift",
                                                                   "Echo/Sources/Features/ConnectionVault/Views/ServerAppearance/ServerColorSwatches.swift"]),
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
                .states(.row("Colour", "the header's colour by default (Settings › Appearance › Current Dock Icon: Header's Color, round 30.1, DK1); the accent with Accent Color or when the header has no colour", token: "ServerHeaderPaint.dockColor"), .row("Fill", "none")),
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
                .behaviour(.row("Order (round 42.1)", "one in every menu: open and create | Copy Name, Script as, Tasks, Open Tool | Refresh and connection | Drop | Properties last"),
                           .row("Icons", "only New, Copy, Refresh, Properties and Drop carry one; ExplorerMenuRules strips the rest"),
                           .row("Hidden, not dimmed", "a command that doesn't apply is left out"), .row("Title", "none")),
                .behaviour(.row("Server (42.5)", "New Query, Activity Monitor, Open Tool ▸ (Maintenance, Extended Events, Database Mail, Availability Groups, CMS) | Copy Name, Color | Refresh, Hide Offline Databases, Edit Connection, Disconnect | Properties")),
                .behaviour(.row("Database (42.3)", "New Query, Query Builder | Back Up, Restore, Copy Name, Tasks ▸, Open Tool ▸ (Maintenance, Security Overview, the advanced objects) | Refresh | Drop | Properties")),
                .behaviour(.row("Table and view (42.4)", "Open Data, Edit Structure, Diagram, New Query | Copy Name, Script as, Tasks ▸ (…, Truncate Table) | Refresh | Drop | Properties; a view has the same shape without what doesn't apply")),
                .behaviour(.row("Column (42.2)", "Open Data Sorted by This Column, Insert in Query | Copy Name, Copy Qualified Name | Rename | Drop Column | Properties (opens Edit Structure)"),
                           .row("Insert in Query", "puts the quoted name at the caret of the query tab on screen (a new tab if none); dragging the column into the editor does the same"),
                           .row("Rename", "the name becomes a field; Return opens the ALTER (sp_rename on SQL Server) in a query tab to read and run; Escape cancels"),
                           .row("Execute a routine (42.2)", "a new tab with EXEC and one line per parameter")),
                .behaviour(.row("Folder (42.6)", "what you can create there first | Filter Tables (an inline field at the top of the folder narrows it as you type; Escape or × removes it) | Refresh last")),
                .behaviour(.row("Empty space (42.6)", "New Connection, Refresh All Servers, Show Empty Folders (the rarer object folders show even when empty; kept between launches)"),
                           .row("Double-click", "a table or view opens its data (Open Data, the first item in its menu)"),
                           .row("Object menu", "the menu bar's Object menu is the selected row's context menu, built by the same code"),
                           .row("check:", "a database has no Diagram yet (Echo only draws a table's); Advanced Objects are four flat items in Open Tool")),
            ], files: ["Echo/Sources/Features/ObjectBrowser/Views/Components/ObjectBrowserSidebarView+ContextMenus.swift", "Echo/Sources/Features/ObjectBrowser/Views/Components/ExplorerMenuRules.swift"]),
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
                .behaviour(.row("Opens elsewhere", "a tool row (it opens a tab, a window or a sheet) ends in arrow.up.right, 11pt tertiary, always shown (round 38: OT1 without its square, MS0, SH0)"),
                           .row("Security Overview", "the first row of every SQL Server Security, the server's and each database's; it opens that Security tab (SN1, DB0)", token: "ExplorerNodeKind.securityOverview")),
            ], rounds: ["ongoing.tree-tool-rows-r38"], files: [components + "ObjectBrowserRowView+Components.swift", "Echo/Sources/Features/ObjectBrowser/Blueprint/ExplorerBlueprint+SQLServer.swift"]),
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
