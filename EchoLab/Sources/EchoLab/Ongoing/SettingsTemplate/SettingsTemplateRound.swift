import SwiftUI

/// Round 43.4 · Settings: the template on other pages. The Editor page's design (43.1 to 43.3: a
/// pinned live preview, pictures for visual choices, short lines, ↺ on changed rows) drawn on three
/// other pages, to check it works as the template. Today those pages are plain grouped forms with no
/// preview (ResultsSettingsView, SidebarSettingsView, AppearanceSettingsView).
@MainActor
enum SettingsTemplateRound {
    static let spec = RoundSpec(
        exhibits: [
            .init(id: "results", title: "Results", summary: "The grid as the preview: row height, stripes, NULL, numbers aligned right.", isWide: true, designWidth: 860, designHeight: 540) { _ in
                LabSTTemplatePage(page: "Results", preview: AnyView(VStack(spacing: SpacingTokens.none) { LabWKGrid(); Spacer(minLength: 0) }.workspaceCard()), sections: [
                    ("Rows", [("Row Height", "Comfortable ⌄"), ("Stripes", "On"), ("Row Numbers", "On")]),
                    ("Values", [("NULL Shows As", "NULL ⌄"), ("Numbers", "Aligned Right"), ("Dates", "2026-10-01 13:49 ⌄")]),
                    ("Fetching", [("Rows Fetched at First", "1,000"), ("Keep Streaming", "On")]),
                ])
            },
            .init(id: "sidebar", title: "Sidebar", summary: "A server card as the preview: size, icons, counts, empty folders.", isWide: true, designWidth: 860, designHeight: 540) { _ in
                LabSTTemplatePage(page: "Sidebar", preview: AnyView(LabSHCard(server: .production, look: .today, rowLimit: 3)), sections: [
                    ("Rows", [("Size", "Medium ⌄"), ("Icons", "Duotone"), ("Counts", "Always")]),
                    ("Folders", [("Show Empty Folders", "Off"), ("Hide Offline Databases", "On")]),
                ])
            },
            .init(id: "appearance", title: "Appearance", summary: "The window as the preview: card corners, accent, motion.", isWide: true, designWidth: 860, designHeight: 540) { _ in
                LabSTTemplatePage(page: "Appearance", preview: AnyView(LabWKWindow(showsInspector: false) { LabWKEditor().workspaceCard() }), sections: [
                    ("Window", [("Card Corners", "16 pt"), ("Gutter", "8 pt")]),
                    ("Colour", [("Accent", "System"), ("Server Colours", "On")]),
                    ("Motion", [("Speed", "Default ⌄")]),
                ])
            },
        ],
        questions: [
            .init(id: "template", title: "The template",
                  question: "Does the Editor page's design work on these three pages?",
                  choices: [.init(id: "yes", name: "TP0 · Yes: make it the template for every page with something to show"),
                            .init(id: "changes", name: "TP1 · Not as it is (say where in the note)")],
                  recommended: "yes",
                  why: "Each page has one thing its settings change (the grid, a server card, the window), so one pinned preview per page holds; the rows below follow 43.3's vocabulary."),
            .init(id: "component", title: "One component",
                  question: "Build the template as one shared settings page component, so pages can't drift apart again?",
                  choices: [.init(id: "yes", name: "TC0 · Yes: a SettingsPage(preview:sections:) in the design system"), .init(id: "no", name: "TC1 · No: follow the pattern by hand")],
                  recommended: "yes",
                  why: "The Editor page is the template because it was designed; a component is the only way the next page gets it for free."),
        ]
    )
}

/// A settings page in the template: sidebar, pinned preview, grouped rows.
struct LabSTTemplatePage: View {
    let page: String
    let preview: AnyView
    let sections: [(String, [(String, String)])]

    var body: some View {
        HStack(spacing: SpacingTokens.none) {
            LabSTSidebar(selected: page)
            Divider()
            VStack(spacing: SpacingTokens.none) {
                preview.frame(height: 170).clipped().padding([.horizontal, .top], SpacingTokens.md)
                Form {
                    ForEach(sections, id: \.0) { title, rows in
                        Section(title) {
                            ForEach(rows, id: \.0) { row in
                                HStack {
                                    Text(row.0)
                                    Spacer()
                                    if row.1 == "On" || row.1 == "Off" { Toggle("", isOn: .constant(row.1 == "On")).labelsHidden().toggleStyle(.switch) }
                                    else { Text(row.1).foregroundStyle(ColorTokens.Text.secondary) }
                                }
                            }
                        }
                    }
                }
                .formStyle(.grouped).scrollContentBackground(.hidden)
            }
        }
        .background(ColorTokens.Background.primary)
    }
}
