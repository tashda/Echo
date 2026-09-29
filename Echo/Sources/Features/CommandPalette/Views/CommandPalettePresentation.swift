import SwiftUI

/// Puts the ⌘K palette over the workspace and the minimised search field in its toolbar, with the
/// search results in a glass card below it (plan K4). Both use their own `CommandPaletteModel`,
/// filled when they open.
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
    @State private var search = CommandPaletteModel()
    @State private var isSearchPresented = false

    func body(content: Content) -> some View {
        content
            .searchable(text: $search.query, isPresented: $isSearchPresented, placement: .toolbar, prompt: "Search")
            // macOS has no `.minimize` behaviour; the toolbar collapses the field to a magnifier
            // on its own when the window is narrow.
            .onSubmit(of: .search) {
                if search.performSelected() { closeSearch() }
            }
            .onChange(of: isSearchPresented) { _, isPresented in
                if isPresented { fill(search) }
            }
            .onChange(of: appState.toolbarSearchFocusRequest) { _, _ in isSearchPresented = true }
            .overlay(alignment: .topTrailing) { searchCard }
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

    // MARK: - Toolbar search

    @ViewBuilder
    private var searchCard: some View {
        if isSearchPresented, !search.query.trimmingCharacters(in: .whitespaces).isEmpty {
            CommandPaletteResultsList(model: search, onPerform: closeSearch)
                .padding(LayoutTokens.FloatingSurface.padding)
                .frame(width: LayoutTokens.CommandPalette.searchCardWidth)
                .glassEffect(.regular, in: .rect(cornerRadius: LayoutTokens.FloatingSurface.cornerRadius, style: .continuous))
                .padding(.top, SpacingTokens.xs)
                .padding(.trailing, SpacingTokens.xs)
                .transition(.opacity)
        }
    }

    private func closeSearch() {
        search.reset()
        isSearchPresented = false
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
