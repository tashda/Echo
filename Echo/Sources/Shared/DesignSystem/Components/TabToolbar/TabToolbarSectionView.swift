import SwiftUI

/// The front tab's section of the window toolbar (round 37.5), at the right before the window's
/// icons: the tab's symbol in grey at the buttons' size (TT8, SC0, SZ1), its special button as a
/// glass capsule with its word (MA1), then its other buttons in one glass capsule split by short
/// hairlines (GR1). Nothing when the tab has no buttons (EM0). The glass reshapes from one tab's
/// buttons into the next (SW2). The query editor's Run keeps its own capsule (RN0).
struct TabToolbarSectionView: View {
    @Environment(TabStore.self) private var tabStore
    @Environment(\.echoMotion) private var motion
    @Namespace private var glass

    var body: some View {
        content
            .animation(motion.standard, value: tabStore.activeTabId)
    }

    @ViewBuilder
    private var content: some View {
        if let tab = tabStore.activeTab {
            if tab.query != nil {
                querySection(tab)
            } else if let section = tab.toolbarSection, !section.isEmpty {
                toolSection(tab, section)
            }
        }
    }

    private func tabSymbol(_ tab: WorkspaceTab) -> some View {
        Image(systemName: tab.kind.icon)
            .font(TypographyTokens.standard)
            .foregroundStyle(ColorTokens.Text.secondary)
            .help("Buttons for \(tab.title)")
            .accessibilityLabel("Buttons for \(tab.title)")
    }

    private func toolSection(_ tab: WorkspaceTab, _ section: TabToolbarSection) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            tabSymbol(tab)
            GlassEffectContainer(spacing: SpacingTokens.xs) {
                HStack(spacing: SpacingTokens.xs) {
                    if let special = section.special {
                        TabToolbarSpecialButton(item: special)
                            .glassEffect(.regular.interactive(), in: .capsule)
                            .glassEffectID("special", in: glass)
                    }
                    if !section.groups.isEmpty {
                        TabToolbarGroupCapsule(groups: section.groups)
                            .glassEffect(.regular, in: .capsule)
                            .glassEffectID("group", in: glass)
                    }
                }
            }
        }
    }

    /// Run in its own capsule (round 24, RN0), then Format · Validate · Help · Plan and, for SQL
    /// Server, SQLCMD · Statistics in one capsule split by a hairline (GR1).
    private func querySection(_ tab: WorkspaceTab) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            tabSymbol(tab)
            GlassEffectContainer(spacing: SpacingTokens.xs) {
                HStack(spacing: SpacingTokens.xs) {
                    QueryRunToolbarControl(tabStore: tabStore)
                        .glassEffectID("special", in: glass)
                    HStack(spacing: SpacingTokens.none) {
                        QueryEditorEnhanceToolbarControls()
                        if tabStore.activeTabToolbarContext.hasDatabaseToggles {
                            TabToolbarHairline()
                            QueryEditorDatabaseToolbarControls()
                        }
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .padding(.horizontal, LayoutTokens.Toolbar.capsuleHorizontalPadding)
                    .padding(.vertical, LayoutTokens.Toolbar.capsuleVerticalPadding)
                    .glassEffect(.regular, in: .capsule)
                    .glassEffectID("group", in: glass)
                }
            }
        }
    }
}

/// A short hairline between two groups in one capsule (GR1).
struct TabToolbarHairline: View {
    var body: some View {
        Rectangle()
            .fill(ColorTokens.Separator.primary)
            .frame(width: SpacingTokens.micro, height: SpacingTokens.md)
            .padding(.horizontal, SpacingTokens.xxxs)
            .accessibilityHidden(true)
    }
}
