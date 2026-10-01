import SwiftUI

/// The tab strip as it is in Echo today: Round 9's plate on one line (decisions 2026-09-30).
/// Values are read from `QueryTabStrip`, `QueryTabButton`, `TabPageChips` and the tokens.
@MainActor
enum TabsArea {
    private static let model = TabsSpecimenModel()
    private static let files = "Echo/Sources/Features/AppHost/Views/Tabs/TabStrip/"

    static let area = LabArea(
        id: "tabs",
        title: "Tabs",
        symbol: "rectangle.topthird.inset.filled",
        summary: "Safari-style tabs on one line: a grey plate with a raised white active tab, a glass + at the end, and a tool's pages unfolding inside its own tab.",
        asBuilt: AsBuiltPage(
            verification: .init(
                level: .code, commit: "ef1c3bba", date: "2026-10-01",
                note: "Read from QueryTabStrip, QueryTabButton (+Title, +CloseButton, +Appearance), TabPageChips and the tab tokens. The specimen is drawn with the same tokens and metrics."),
            stageHeight: 150,
            behaviours: [
                .init(trigger: "Click a tab", result: "Selects on press, so the click counts at once; dragging still reorders. Pressing the close button doesn't select the tab. The highlight moves at once, as in Safari; only a tool tab unfolding or folding its pages springs."),
                .init(trigger: "Switch back to a recent tab", result: "Its editor is still alive: scroll, undo history and cursor stay. The six most recent tabs stay loaded (KeptAliveTabsView.keptTabCount); an older one is rebuilt, and the one that drops out is unloaded a second later."),
                .init(trigger: "Hover a tab", result: "The close × appears at its leading edge; the tooltip shows title, database and running time."),
                .init(trigger: "Middle-click a tab", result: "Closes it."),
                .init(trigger: "Query running", result: "A spinner replaces the tab's icon."),
                .init(trigger: "Many tabs", result: "Tabs share the width equally and simply get narrower. There is no minimum width and no collapse to icons in the code; the earlier plan (B3) was superseded."),
                .init(trigger: "Click +", result: "Opens a new query tab."),
                .init(trigger: "Open a tool with pages", result: "The active tool tab widens and shows its pages as chips after its title; the other tabs share what is left."),
                .init(trigger: "Drag a tab", result: "It follows the pointer; the others make room; separators next to it hide."),
            ],
            motions: [
                .init(name: "Unfold pages", curve: "snappy, extra bounce 0.06", duration: "0.32s", note: "QueryTabStrip.unfoldAnimation; only when the unfolded tab changes, not on a plain switch"),
                .init(name: "Plain tab switch", curve: "none", duration: "instant", note: "decided 2026-10-01"),
                .init(name: "Reorder while dragging", curve: "interactive spring, response 0.2, damping 0.9", duration: "interactive", note: "tabReorderAnimation"),
                .init(name: "Page chip selection", curve: "snappy", duration: "0.22s"),
            ],
            measurements: [
                .init(label: "Strip height", value: "32pt", token: "WorkspaceChromeMetrics.tabStripTotalHeight"),
                .init(label: "Plate height", value: "28pt", token: "WorkspaceChromeMetrics.chromeBackgroundHeight"),
                .init(label: "Plate corner", value: "14pt continuous", token: "basePlateCornerRadius"),
                .init(label: "Tab height", value: "24pt", token: "WorkspaceChromeMetrics.tabHeight"),
                .init(label: "Tab corner", value: "15pt continuous", token: "QueryTabButton.tabCornerRadius"),
                .init(label: "Title", value: "11pt regular", token: "TypographyTokens.detail"),
                .init(label: "+ button", value: "28pt glass circle", token: "newTabButtonSize"),
            ],
            rules: [
                .init(text: "Tabs look and behave like Safari's",
                      why: "The reference every Mac user already knows.",
                      rounds: ["ported.Round 14 · tab bar and pages"]),
                .init(text: "Round 9's plate on one line",
                      why: "The glass capsule with two lines was regretted; N1, N1R and N4 to N9 were rejected.",
                      rounds: ["decided.round9-footer-scroller-tabs", "decided.round13-tab-directions", "ported.Round 14 · tab bar and pages"]),
                .init(text: "The database is in the tooltip",
                      why: "One line keeps the strip calm.",
                      rounds: ["decided.round12-two-line-tabs"]),
                .init(text: "A plain tab switch moves the highlight at once",
                      why: "As native tab bars do. Springing every tab's colours re-rendered the strip for ~0.7 s on each switch. Owner's choice, 2026-10-01.",
                      rounds: []),
                .init(text: "A tool's pages unfold inside its tab (ST2)",
                      why: "Replaces the segmented control at the top of tool tabs.",
                      rounds: ["ported.Round 14 · tab bar and pages"]),
            ],
            code: [files, files + "QueryTabButton*.swift", files + "TabPageChips.swift", "Packages/EchoDesignSystem/Sources/EchoDesignSystem/Tokens/ColorToken.swift"]
        ) {
            TabsSpecimen(model: model)
        },
        spec: AreaSpec(code: "TABS", stageHeight: 130, parts: parts) {
            TabsSpecimen(model: model)
        }
        .controls { TabsSpecControls(model: model) }
        .onState { model.forced = $0 }
    )

    private static let parts: [SpecPart] = [
        SpecPart(number: "1", name: "Strip", summary: "The band above the cards that holds the plate, the tabs and the + button.", elements: [
            SpecElement(number: "1.1", name: "Strip area", summary: "Sits on the canvas above both cards, the way Safari's tab bar sits above the page.", groups: [
                .layout(.row("Height", "32pt", token: "WorkspaceChromeMetrics.tabStripTotalHeight"),
                        .row("Horizontal inset", "8pt from the card edge, plus the plate's 2pt", token: "leadingPadding + baseHorizontalInset"),
                        .row("Clipping", "clipped to the strip")),
            ], rounds: ["ported.Round 14 · tab bar and pages"], files: [files + "QueryTabStrip.swift"]),
            SpecElement(number: "1.2", name: "Plate", summary: "The grey plate the tabs sit on. It hugs the tabs; it does not stretch across the window.", groups: [
                .material(.row("Fill", "grey; darker with Increase Contrast", token: "ColorTokens.TabStrip.Background.plate", swatch: ColorTokens.TabStrip.Background.plate),
                          .row("Glass", "none"), .row("Edge", "none in the standard style"), .row("Shadow", "none")),
                .layout(.row("Height", "28pt, centred in the 32pt strip", token: "chromeBackgroundHeight"),
                        .row("Corner", "14pt continuous", token: "basePlateCornerRadius"),
                        .row("Width", "tab group + 2pt inset each side, never wider than the space available", token: "desiredPlateWidth")),
            ], rounds: ["decided.round9-footer-scroller-tabs"], files: [files + "TabStripBackground.swift"]),
            SpecElement(number: "1.3", name: "Tab group", summary: "All tabs and their separators, laid out edge to edge.", groups: [
                .layout(.row("Tab width", "equal share of the space left after the + and the separators", token: "effectiveWidth / count"),
                        .row("Space reserved for +", "28pt + 6pt gap"),
                        .row("Tab spacing", "0; separators take one hairline each")),
            ], files: [files + "QueryTabStrip.swift"]),
        ]),
        SpecPart(number: "2", name: "Tab", summary: "One tab: close ×, icon, title, and their states.", elements: [
            SpecElement(number: "2.1", name: "Tab", summary: "The shape every tab shares.", groups: [
                .layout(.row("Height", "24pt minimum", token: "WorkspaceChromeMetrics.tabHeight"),
                        .row("Corner", "15pt continuous", token: "QueryTabButton.tabCornerRadius"),
                        .row("Padding", "8 leading · 12 trailing · 2 vertical", token: "SpacingTokens.xs / sm / xxxs"),
                        .row("Content", "× · icon and title centred · 12pt spacer")),
            ], files: [files + "QueryTabButton.swift"]),
            SpecElement(number: "2.2", name: "Icon", summary: "The tab's kind icon (query, tool, table…).", groups: [
                .type(.row("Symbol size", "11pt", token: "TypographyTokens.detail"), .row("Frame", "14pt wide", token: "SpacingTokens.sm2"), .row("Gap to the title", "6pt", token: "SpacingTokens.xxs2")),
                .states(.row("Active", "title colour at 80%"), .row("Inactive", "title colour at 70%")),
            ], files: [files + "QueryTabButton+Title.swift"]),
            SpecElement(number: "2.3", name: "Title", summary: "One line, centred in what is left.", groups: [
                .type(.row("Font", "11pt regular", token: "TypographyTokens.detail"),
                      .row("Alignment", "centred between × and the right spacer"),
                      .row("Lines", "1, truncated at the end"),
                      .row("Active colour", "label", token: "NSColor.labelColor"),
                      .row("Inactive colour", "secondary label", token: "NSColor.secondaryLabelColor")),
            ], files: [files + "QueryTabButton+Title.swift"]),
            SpecElement(number: "2.4", name: "Active tab", summary: "The raised white tab. No glass.", states: [SpecState(key: "hoverActive", name: "Hovered")], groups: [
                .material(.row("Fill", "vertical gradient, near white", token: "ColorTokens.TabStrip.ActiveTab.Light", swatch: ColorTokens.TabStrip.ActiveTab.Light.top),
                          .row("Dark appearance", "white 26% to 18%", token: "ActiveTab.Dark"),
                          .row("Edge", "hairline, light grey (dark: white 30%)", token: "Border.activeLight / activeDark"),
                          .row("Shadow", "black 10% (dark 28%), radius 2.5, y 1.2", token: "Shadow.light / dark"),
                          .row("Glass", "none")),
                .states(.row("Hover", "slightly lighter gradient", token: "ActiveTab.hoverTop / hoverBottom")),
            ], rounds: ["decided.round9-footer-scroller-tabs"], files: [files + "QueryTabButton+Appearance.swift"]),
            SpecElement(number: "2.5", name: "Inactive tab", summary: "No fill and no edge; the plate shows through.", groups: [
                .material(.row("Fill", "none"), .row("Edge", "none"), .row("Title", "secondary label"), .row("Icon", "70%")),
            ], files: [files + "QueryTabButton+Appearance.swift"]),
            SpecElement(number: "2.6", name: "Inactive tab, hovered", summary: "A soft grey gradient appears under the pointer.", states: [SpecState(key: "hoverInactive", name: "Hovered")], defaultState: "hoverInactive", groups: [
                .material(.row("Fill", "gradient light grey", token: "TabStrip.InactiveHover.Light", swatch: ColorTokens.TabStrip.InactiveHover.Light.top),
                          .row("Edge", "hairline, white 68% (dark 22%)", token: "Border.hoverLight / hoverDark")),
            ], files: [files + "QueryTabButton+Appearance.swift"]),
            SpecElement(number: "2.7", name: "Close ×", summary: "Safari-style: at the tab's leading edge, and only while the tab is hovered.", states: [SpecState(key: "hoverActive", name: "Tab hovered"), SpecState(key: "hoverClose", name: "× hovered")], defaultState: "hoverActive", groups: [
                .type(.row("Glyph", "xmark, 9pt bold", token: "TypographyTokens.compact")),
                .layout(.row("Hit area", "a circle in the 14pt icon frame", token: "SpacingTokens.sm2"), .row("Position", "leading edge of the tab")),
                .states(.row("Visible", "only while the tab is hovered; never on pinned tabs"),
                        .row("Active tab", "secondary label"), .row("Inactive tab", "tertiary label"),
                        .row("Hovering the ×", "label colour on a circle: black 8% (dark: white 18%)")),
                .behaviour(.row("Tooltip", "Close tab"), .row("Middle-click", "closes the tab")),
            ], files: [files + "QueryTabButton+CloseButton.swift"]),
            SpecElement(number: "2.8", name: "Drop target", summary: "The tab a dragged item will land on.", states: [SpecState(key: "dropTarget", name: "Drop target")], defaultState: "dropTarget", groups: [
                .material(.row("Fill", "grey gradient (dark: white 24% to 18%)", token: "TabStrip.DropTarget"), .row("Title", "white")),
            ], files: [files + "QueryTabButton+Appearance.swift"]),
            SpecElement(number: "2.9", name: "Pinned tab", summary: "A narrow tab showing one letter. Turn on \"Pinned tab\" to see it.", groups: [
                .type(.row("Title", "first letter, uppercased, 11pt semibold; a dot for an empty title"), .row("Colour", "label; inactive at 75% secondary")),
                .layout(.row("Padding", "13pt each side"), .row("Close", "none")),
            ], files: [files + "QueryTabButton+Title.swift"]),
            SpecElement(number: "2.10", name: "Running spinner", summary: "Replaces the icon while a query runs.", groups: [
                .layout(.row("Control", "mini progress spinner in the icon's 12pt frame")),
                .behaviour(.row("Timer", "in the tooltip and the tab overview, not on the tab")),
            ], files: [files + "QueryTabButton+Title.swift"]),
            SpecElement(number: "2.11", name: "Tooltip", summary: "Title, database, and when a running query started.", groups: [
                .behaviour(.row("Format", "Title · database · Running since 10:42:03; the database is the tab's subtitle or its active database")),
            ], rounds: ["decided.round12-two-line-tabs"], files: [files + "QueryTabButton+Title.swift"]),
            SpecElement(number: "2.12", name: "Context menu", summary: "Right-click a tab.", groups: [
                .behaviour(.row("Items", "Pin Tab or Unpin Tab; Duplicate Tab; Switch Database (a submenu with a check on the current one, when the connection has databases); Close Tab; Close Other Tabs; Close Tabs to the Left; Close Tabs to the Right; Add to Bookmarks (when offered)"),
                           .row("Disabled", "Duplicate, Close Others and the left and right closes when they would do nothing")),
            ], files: [files + "QueryTabButton.swift"]),
            SpecElement(number: "2.13", name: "Drag to reorder", summary: "Tabs follow the pointer and the others slide aside.", groups: [
                .motion(.row("Spring", "interactive, response 0.2, damping 0.9", token: "tabReorderAnimation")),
            ], files: [files + "QueryTabStrip+DragReorder.swift"]),
        ]),
        SpecPart(number: "3", name: "Separator", summary: "The hairline between tabs.", elements: [
            SpecElement(number: "3.1", name: "Separator", summary: "A thin capsule that fades near the active or hovered tab.", groups: [
                .layout(.row("Width", "one device pixel (never under 0.5pt)", token: "tabHairlineWidth()"), .row("Height", "18pt"), .row("Vertical inset", "8pt")),
                .material(.row("Fill", "vertical gradient, grey (dark: white 28% to 16%)", token: "TabStrip.Separator.Light", swatch: ColorTokens.TabStrip.Separator.Light.top)),
                .states(.row("Hidden", "next to the active tab, next to a hovered tab, and around a dragged tab")),
            ], files: [files + "QueryTabStrip+Separators.swift"]),
        ]),
        SpecPart(number: "4", name: "New tab", summary: "The + at the end of the strip.", elements: [
            SpecElement(number: "4.1", name: "New tab button", summary: "A glass circle, the one place in the strip that uses Liquid Glass.", groups: [
                .material(.row("Glass", "Liquid Glass, regular, circle"), .row("Hover", "primary at 6% inside the circle")),
                .layout(.row("Size", "28pt", token: "newTabButtonSize"), .row("Gap to the last tab", "6pt", token: "newTabButtonGap"),
                        .row("Position", "ends at the card's trailing edge")),
                .type(.row("Glyph", "plus, 14pt medium", token: "TypographyTokens.prominent")),
                .behaviour(.row("Tooltip", "New Tab")),
            ], files: [files + "QueryTabStrip.swift"]),
        ]),
        SpecPart(number: "5", name: "Tool pages", summary: "A tool's pages, shown inside its active tab.", elements: [
            SpecElement(number: "5.1", name: "Page chips", summary: "Small chips after the tool tab's title (ST2). Turn on \"Tool pages\" and select Activity Monitor.", groups: [
                .material(.row("Track", "capsule, primary at 6%", token: "TabStrip.Pages.track"),
                          .row("Selected chip", "text background with a faint shadow", token: "Pages.selected / selectedShadow")),
                .type(.row("Font", "10pt; selected semibold", token: "TypographyTokens.label")),
                .layout(.row("Track height", "20pt", token: "LayoutTokens.TabPages.chipHeight"),
                        .row("Chip padding", "8pt horizontal", token: "chipHorizontalPadding"),
                        .row("Chip spacing", "2pt", token: "TabPages.spacing")),
                .motion(.row("Selection", "snappy, 0.22s")),
            ], rounds: ["ported.Round 14 · tab bar and pages"], files: [files + "TabPageChips.swift"]),
            SpecElement(number: "5.2", name: "Unfolded width", summary: "How wide the tool tab becomes.", groups: [
                .layout(.row("Ideal width", "title + pages + 76pt chrome", token: "TabPageChipsMetrics.idealWidth"),
                        .row("Never narrower", "than its equal share of the strip"), .row("Largest share of the strip", "62%", token: "LayoutTokens.TabPages.maxShareOfStrip"),
                        .row("Other tabs", "share what is left equally")),
                .motion(.row("Unfold", "snappy, extra bounce 0.06, 0.32s; only when the unfolded tab changes", token: "unfoldAnimation"),
                        .row("Plain switch", "instant")),
            ], files: [files + "QueryTabStrip+Unfold.swift"]),
        ]),
        SpecPart(number: "6", name: "Not built", summary: "Things the plan mentioned that Echo does not do (yet).", elements: [
            SpecElement(number: "6.1", name: "Collapse inactive tabs to icons", summary: "Plan B3: a minimum tab width, then inactive tabs shrink to their icon. Not in the code; tabs only get narrower.", isRetired: true),
        ]),
    ]
}

private struct TabsSpecControls: View {
    @Bindable var model: TabsSpecimenModel

    var body: some View {
        HStack(spacing: SpacingTokens.md) {
            Stepper("Tabs: \(model.count)", value: $model.count, in: 1...12)
            Toggle("Query running", isOn: $model.isRunning)
            Toggle("Tool pages", isOn: $model.showsPages)
            Toggle("Pinned tab", isOn: $model.hasPinned)
            Spacer()
        }
    }
}
