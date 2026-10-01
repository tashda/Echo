import SwiftUI
import SQLServerKit

struct ResourceGovernorView: View {
    @Bindable var viewModel: ResourceGovernorViewModel

    @State var showNewPoolSheet = false
    @State var showNewGroupSheet = false
    @State var pendingDropPool: String?
    @State var pendingDropGroup: String?
    @State private var poolsFraction: CGFloat = 0.5

    var body: some View {
        // TT1: pools and workload groups as two cards; the state after the server (round 37.2),
        // the buttons in the window toolbar (37.5).
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .adaptiveWorkspaceCard()
            .tabContentFrame()
            .tabToolbar(special: applyChangesItem, groups: [toolbarGroup])
            .toolTabHeaderDetail(configurationDetail)
        .onAppear {
            viewModel.refresh()
        }
        .sheet(isPresented: $showNewPoolSheet) {
            NewResourcePoolSheet(viewModel: viewModel) { showNewPoolSheet = false }
        }
        .sheet(isPresented: $showNewGroupSheet) {
            NewWorkloadGroupSheet(viewModel: viewModel) { showNewGroupSheet = false }
        }
        .alert("Drop Resource Pool?", isPresented: Binding(
            get: { pendingDropPool != nil },
            set: { if !$0 { pendingDropPool = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingDropPool = nil }
            Button("Drop", role: .destructive) {
                if let name = pendingDropPool {
                    pendingDropPool = nil
                    Task { await viewModel.dropPool(name: name) }
                }
            }
        } message: {
            Text("Are you sure you want to drop the pool \(pendingDropPool ?? "")? This action cannot be undone.")
        }
        .alert("Drop Workload Group?", isPresented: Binding(
            get: { pendingDropGroup != nil },
            set: { if !$0 { pendingDropGroup = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingDropGroup = nil }
            Button("Drop", role: .destructive) {
                if let name = pendingDropGroup {
                    pendingDropGroup = nil
                    Task { await viewModel.dropGroup(name: name) }
                }
            }
        } message: {
            Text("Are you sure you want to drop the workload group \(pendingDropGroup ?? "")? This action cannot be undone.")
        }
    }
    
    /// "Enabled · classifier dbo.fn" after the server.
    private var configurationDetail: String? {
        guard let config = viewModel.configuration else { return nil }
        var parts = [config.isEnabled ? "Enabled" : "Disabled"]
        if let classifier = config.classifierFunction { parts.append("classifier \(classifier)") }
        return parts.joined(separator: " · ")
    }

    /// Round 37.5: Apply Changes is the special button while a reconfigure is pending.
    private var applyChangesItem: TabToolbarItem? {
        guard viewModel.configuration?.isReconfigurationPending == true else { return nil }
        return TabToolbarItem(id: "applyChanges", title: "Apply Changes", symbol: "checkmark.circle") { [viewModel] in
            Task { await viewModel.reconfigure() }
        }
    }

    /// Enable or Disable, and Refresh.
    private var toolbarGroup: [TabToolbarItem] {
        var items: [TabToolbarItem] = []
        if let config = viewModel.configuration {
            items.append(TabToolbarItem(id: "enable", title: config.isEnabled ? "Disable Resource Governor" : "Enable Resource Governor",
                                        symbol: "power", isDisabled: viewModel.isToggling, isOn: config.isEnabled, isToggle: true) { [viewModel] in
                Task { await viewModel.toggleEnabled() }
            })
        }
        items.append(.refresh(isBusy: viewModel.isRefreshing) { [viewModel] in viewModel.refresh() })
        return items
    }

    @ViewBuilder
    private var content: some View {
        if !viewModel.hasLoaded {
            initialState
        } else {
            CardSplitView(axis: .vertical, fraction: $poolsFraction, minFraction: 0.25) {
                poolsSection
            } second: {
                groupsSection
            }
        }
    }

    @ViewBuilder
    private var initialState: some View {
        if let error = viewModel.errorMessage, !viewModel.isRefreshing {
            TabContentUnavailableView("Could Not Load Resource Governor", systemImage: "exclamationmark.triangle") {
                Text(error)
            } actions: {
                Button("Try Again") { viewModel.refresh() }
                    .buttonStyle(.bordered)
            }
        } else {
            TabInitializingPlaceholder(
                icon: "slider.horizontal.3",
                title: "Loading Resource Governor",
                subtitle: "Fetching resource pools and workload groups…"
            )
        }
    }
}
