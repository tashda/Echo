import SwiftUI
import Combine
import EchoSense

struct SearchSidebarView: View {
    @Environment(ProjectStore.self) var projectStore
    @Environment(ConnectionStore.self) var connectionStore
    @Environment(NavigationStore.self) var navigationStore
    @Environment(TabStore.self) var tabStore
    
    @EnvironmentObject var environmentState: EnvironmentState
    @StateObject var viewModel = SearchSidebarViewModel()
    @FocusState var isSearchFieldFocused: Bool
    @State var didRestoreCache = false
    @State var activeCacheKey: SearchSidebarContextKey?
    @State var isFilterPopoverPresented = false

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            content
                .padding(SpacingTokens.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            if !didRestoreCache {
                didRestoreCache = true
                syncContext(forceRestore: true)
            } else {
                syncContext()
            }
            viewModel.setQueryTabProvider { [weak environmentState] in
                queryTabSnapshots(from: environmentState)
            }
            viewModel.notifyQueryTabsChanged()
        }
        .onChange(of: connectionStore.selectedConnectionID) { _, _ in syncContext() }
        .onChange(of: activeSession?.id) { _, _ in syncContext() }
        .onChange(of: activeSession?.selectedDatabaseName) { _, _ in syncContext() }
        .onReceive(viewModel.$query.removeDuplicates()) { _ in cacheState() }
        .onReceive(viewModel.$selectedCategories.removeDuplicates()) { _ in cacheState() }
        .onReceive(viewModel.$results) { _ in cacheState() }
        .onReceive(viewModel.$errorMessage.removeDuplicates()) { _ in cacheState() }
        .onReceive(viewModel.$isSearching.removeDuplicates()) { _ in cacheState() }
        .onChange(of: tabStore.tabs.map(\.id)) { _, _ in
            viewModel.notifyQueryTabsChanged()
        }
        .onChange(of: tabStore.activeTabId) { _, _ in
            viewModel.notifyQueryTabsChanged()
        }
        .onDisappear { persistActiveCache() }
    }

    var activeSession: ConnectionSession? {
        if let selectedID = connectionStore.selectedConnectionID,
           let session = environmentState.sessionCoordinator.sessionForConnection(selectedID) {
            return session
        }
        return environmentState.sessionCoordinator.activeSession
    }
}

enum SearchSidebarConstants {
    static let scrollSpace = "SearchSidebarScrollSpace"
}
