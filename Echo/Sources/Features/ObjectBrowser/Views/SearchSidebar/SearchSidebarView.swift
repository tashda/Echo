import SwiftUI
import EchoSense

struct SearchSidebarView: View {
    @Environment(ProjectStore.self) var projectStore
    @Environment(ConnectionStore.self) var connectionStore
    @Environment(NavigationStore.self) var navigationStore
    @Environment(TabStore.self) var tabStore

    @Environment(EnvironmentState.self) var environmentState
    @State var viewModel = SearchSidebarViewModel()
    @State var didRestoreCache = false
    @State var isFilterPopoverPresented = false

    var body: some View {
        VStack(spacing: 0) {
            SearchSidebarSearchBar(
                viewModel: viewModel,
                isFilterPopoverPresented: $isFilterPopoverPresented
            )

            content
        }
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
        .onChange(of: environmentState.sessionGroup.sessions.map(\.id)) { _, _ in syncContext() }
        .onChange(of: tabStore.tabs.map(\.id)) { _, _ in
            viewModel.notifyQueryTabsChanged()
        }
        .onChange(of: tabStore.activeTabId) { _, _ in
            viewModel.notifyQueryTabsChanged()
        }
        .onDisappear { persistCache() }
    }
}

enum SearchSidebarConstants {
    static let scrollSpace = "SearchSidebarScrollSpace"
}
