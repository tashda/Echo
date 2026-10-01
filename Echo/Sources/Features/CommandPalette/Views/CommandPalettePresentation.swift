import SwiftUI

/// Puts the ⌘K palette over the workspace (plan K4). The toolbar's magnifier and ⌥⌘F open the
/// same palette, so search works one way everywhere (owner, 2026-09-30: no toolbar search field).
struct CommandPalettePresentation: ViewModifier {
    @Environment(AppState.self) private var appState
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(TabStore.self) private var tabStore
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(NavigationStore.self) private var navigationStore
    @Environment(ProjectStore.self) private var projectStore
    @Environment(ClipboardHistoryStore.self) private var clipboardHistory
    @Environment(\.echoMotion) private var motion

    @State private var palette = CommandPaletteModel()

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) { paletteLayer }
            .onChange(of: appState.isCommandPaletteVisible) { _, isVisible in
                if isVisible { fill(palette) }
            }
            .animation(motion.standard, value: appState.isCommandPaletteVisible)
    }

    // MARK: - Palette

    @ViewBuilder
    private var paletteLayer: some View {
        if appState.isCommandPaletteVisible {
            ZStack(alignment: .top) {
                // A click anywhere outside the card closes it.
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { appState.isCommandPaletteVisible = false }
                CommandPaletteCard(model: palette) { appState.isCommandPaletteVisible = false }
                    .padding(.top, LayoutTokens.CommandPalette.topInset)
                    .transition(.scale(scale: 0.96, anchor: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Filling

    private func fill(_ model: CommandPaletteModel) {
        let sources = CommandPaletteSources(
            environmentState: environmentState,
            tabStore: tabStore,
            connectionStore: connectionStore,
            navigationStore: navigationStore,
            clipboardHistory: clipboardHistory
        )
        model.reset()
        model.localItems = sources.localItems()
        model.objectItem = { sources.objectItem(for: $0) }
        model.objectSearch.applySettings(projectStore.globalSettings)
        model.objectSearch.updateSessions(environmentState.sessionGroup.activeSessions)
    }
}

extension View {
    func commandPalette() -> some View {
        modifier(CommandPalettePresentation())
    }
}
