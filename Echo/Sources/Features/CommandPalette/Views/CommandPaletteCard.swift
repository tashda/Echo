import SwiftUI

/// The ⌘K palette (plan K4): a centred glass card with a field and the matching rows. Arrows move
/// the selection, Return performs it, Esc closes. Its tab overview scope (round 35.1, TO6) lists
/// this window's tabs and their state, with keys to close and duplicate them.
struct CommandPaletteCard: View {
    @Bindable var model: CommandPaletteModel
    @Bindable var tabOverview: TabOverviewPaletteModel
    let scope: CommandPaletteScope
    let onClose: () -> Void

    @State var keyMonitor: Any?

    @Environment(TabStore.self) var tabStore
    @Environment(EnvironmentState.self) var environmentState

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            field
            switch scope {
            case .everything:
                if !model.results.isEmpty || !model.query.isEmpty {
                    CommandPaletteResultsList(model: model, onPerform: onClose)
                }
            case .tabs:
                TabOverviewPaletteList(model: tabOverview, onOpen: openTab)
            }
            hints
        }
        .padding(LayoutTokens.FloatingSurface.padding)
        .frame(width: LayoutTokens.CommandPalette.width)
        // Glass on the card itself, not a GlassEffectContainer: a text field inside a container
        // sent AppKit's autofill into an endless key-view walk (round 10).
        .glassEffect(.regular, in: .rect(cornerRadius: LayoutTokens.FloatingSurface.cornerRadius, style: .continuous))
        .onAppear { updateKeyMonitor(for: scope) }
        .onChange(of: scope) { _, newScope in updateKeyMonitor(for: newScope) }
        .onDisappear { removeKeyMonitor() }
    }

    private var field: some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: scope == .tabs ? "square.grid.2x2" : "magnifyingglass")
                .font(TypographyTokens.prominent)
                .foregroundStyle(ColorTokens.Text.secondary)
            // One field for both scopes, so it keeps the keyboard when "Tab Overview" turns the
            // palette to the tabs.
            CommandPaletteSearchField(
                text: scope == .tabs ? $tabOverview.query : $model.query,
                placeholder: scope == .tabs ? "Tab Overview: search this window's tabs" : "Search objects, tabs, actions and snippets",
                onMove: { offset in
                    if scope == .tabs {
                        tabOverview.moveSelection(by: offset, in: shownTabs, activeID: tabStore.activeTabId)
                    } else {
                        model.moveSelection(by: offset)
                    }
                },
                onSubmit: {
                    if scope == .tabs {
                        if let id = selectedTabID { openTab(id) }
                    } else if model.performSelected() {
                        onClose()
                    }
                },
                onCancel: onClose,
                onKeyCommand: { scope == .tabs ? performTabKey($0) : false }
            )
        }
        .padding(.horizontal, SpacingTokens.xs)
        .frame(height: LayoutTokens.CommandPalette.fieldHeight)
    }

    /// What the keys do, so the palette teaches itself.
    private var hints: some View {
        HStack(spacing: SpacingTokens.sm) {
            switch scope {
            case .everything:
                Text("↑↓ Move")
                Text("↩ Open")
                Text("⎋ Close")
            case .tabs:
                Text("↩ Go to Tab")
                Text("⌫ Close Tab")
                Text("⌘D Duplicate")
                Text("⌥⌫ Close Others")
                Text("⎋ Done")
            }
            Spacer(minLength: SpacingTokens.none)
        }
        .font(TypographyTokens.detail)
        .foregroundStyle(ColorTokens.Text.tertiary)
        .padding(.horizontal, SpacingTokens.xs)
        .padding(.top, SpacingTokens.xxs)
        .accessibilityHidden(true)
    }
}
