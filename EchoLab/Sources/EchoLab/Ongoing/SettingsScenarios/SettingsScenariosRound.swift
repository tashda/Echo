import SwiftUI

/// Round 43.5 · Settings: search, reset and overrides. Echo today: Settings has a sidebar of 12 pages
/// and no search; nothing shows which settings you changed; there is no Reset; settings are global.
/// Cloud sync carries connections and bookmarks; settings sync is planned but not built.
@MainActor
enum SettingsScenariosRound {
    enum Search: String, CaseIterable {
        case none = "SE0 · No search (today)"
        case sidebar = "SE1 · A search field atop the sidebar: matching pages stay, matching rows are marked"
        case results = "SE2 · A search field that lists matching settings across pages, like System Settings"
    }

    static let spec = RoundSpec(
        controls: [
            .of("search", "Search", Search.self, default: .results,
                question: "Type 'gutter' in each exhibit. Which finds the setting fastest?",
                recommend: .results,
                why: "System Settings' search: one list of matching settings with the page each lives on, and choosing one opens the page with the row highlighted. Filtering the sidebar alone leaves you hunting on the page."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "No search.", isEchoToday: true, isWide: true, designWidth: 860, designHeight: 480) { _ in
                LabSTSearchScene(search: .none)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the control, searching 'gutter'.", isWide: true, designWidth: 860, designHeight: 480) { values in
                LabSTSearchScene(search: Search(rawValue: values["search"]) ?? .results)
            },
        ],
        questions: [
            .init(id: "modified", title: "What you changed",
                  question: "Should the sidebar show which pages have settings you changed?",
                  choices: [.init(id: "dot", name: "MD0 · A small dot beside the page; the rows show ↺ (43.3)"), .init(id: "none", name: "MD1 · No")],
                  recommended: "dot",
                  why: "'Why does my editor look different from yours?' gets answered in one glance."),
            .init(id: "reset", title: "Resetting a page",
                  question: "Should each page have Reset to Defaults?",
                  choices: [.init(id: "page", name: "RP0 · Yes, at the bottom of each page, with a confirmation"), .init(id: "none", name: "RP1 · No, ↺ per row is enough")],
                  recommended: "page",
                  why: "After trying many settings, one button back to a known state is reassuring; at the bottom it is never hit by accident."),
            .init(id: "perConnection", title: "Per connection",
                  question: "Should some settings be set per connection (font size on a demo server, a row limit on production)?",
                  choices: [.init(id: "few", name: "PC0 · A few, chosen deliberately, shown with the connection's colour dot beside the row"),
                            .init(id: "none", name: "PC1 · No: settings are global")],
                  recommended: "few",
                  why: "Production servers are where people want guard rails (row limits, confirm before UPDATE); everything else stays global so Settings stays one place."),
            .init(id: "sync", title: "Sync",
                  question: "Which settings sync to your other Macs?",
                  choices: [.init(id: "look", name: "SY0 · Everything except window sizes and this Mac's paths"), .init(id: "none", name: "SY1 · None")],
                  recommended: "look",
                  why: "Echo already syncs connections and bookmarks; the editor and results looking the same on both Macs is what people expect."),
        ],
        presets: [.init(id: "recommended", name: "My recommendation", values: ["search": Search.results.rawValue], isRecommended: true)]
    )
}

private struct LabSTSearchScene: View {
    let search: SettingsScenariosRound.Search

    var body: some View {
        HStack(spacing: SpacingTokens.none) {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                if search != .none {
                    HStack(spacing: SpacingTokens.xxs2) {
                        Image(systemName: "magnifyingglass").foregroundStyle(ColorTokens.Text.secondary)
                        Text("gutter")
                        Spacer()
                    }
                    .font(TypographyTokens.standard).padding(.horizontal, SpacingTokens.xs).frame(height: SpacingTokens.lg2 - SpacingTokens.xxxs)
                    .background(ColorTokens.Sidebar.hoverFill, in: .rect(cornerRadius: SpacingTokens.xs))
                    .padding([.horizontal, .top], SpacingTokens.xs)
                }
                if search == .results {
                    VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                        ForEach([("Line Numbers", "Editor › Gutter"), ("Gutter Style", "Editor › Gutter"), ("Gutter Width", "Appearance › Window")], id: \.0) { item in
                            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                                Text(item.0).font(TypographyTokens.standard)
                                Text(item.1).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                            }
                            .padding(SpacingTokens.xs).frame(maxWidth: .infinity, alignment: .leading)
                            .background(item.0 == "Gutter Style" ? ColorTokens.Sidebar.selectedFill : .clear, in: .rect(cornerRadius: SpacingTokens.xxs2))
                        }
                    }
                    .padding(.horizontal, SpacingTokens.xs)
                    Spacer()
                } else {
                    LabSTSidebar(selected: "Editor", only: search == .sidebar ? ["Editor", "Appearance"] : nil).frame(maxHeight: .infinity)
                }
            }
            .frame(width: 200)
            .background(ColorTokens.Background.secondary)
            Divider()
            Form {
                Section("Gutter") {
                    HStack { Text("Line Numbers"); Spacer(); Toggle("", isOn: .constant(true)).labelsHidden().toggleStyle(.switch) }
                    HStack { Text("Style"); Spacer(); Text("Subtle").foregroundStyle(ColorTokens.Text.secondary) }
                        .padding(SpacingTokens.xxs)
                        .background(search == .none ? Color.clear : ColorTokens.accent.opacity(0.14), in: .rect(cornerRadius: SpacingTokens.xxs2))
                }
                Section("While Typing") {
                    HStack { Text("Statement Focus"); Spacer(); Toggle("", isOn: .constant(true)).labelsHidden().toggleStyle(.switch) }
                }
            }
            .formStyle(.grouped).scrollContentBackground(.hidden)
        }
        .background(ColorTokens.Background.primary)
    }
}
