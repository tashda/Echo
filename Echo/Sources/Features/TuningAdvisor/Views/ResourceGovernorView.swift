import SwiftUI
import SQLServerKit

struct ResourceGovernorView: View {
    @Bindable var viewModel: ResourceGovernorViewModel

    @State var showNewPoolSheet = false
    @State var showNewGroupSheet = false
    @State var pendingDropPool: String?
    @State var pendingDropGroup: String?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .background(ColorTokens.Background.primary)
        .tabContentFrame()
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
    
    private var toolbar: some View {
        TabSectionToolbar {
            configurationControls
        } controls: {
            TabRefreshButton(isRefreshing: viewModel.isRefreshing) {
                viewModel.refresh()
            }
        }
    }

    @ViewBuilder
    private var configurationControls: some View {
        if let config = viewModel.configuration {
            Label(
                config.isEnabled ? "Enabled" : "Disabled",
                systemImage: config.isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill"
            )
            .font(TypographyTokens.detail)
            .foregroundStyle(config.isEnabled ? ColorTokens.Status.success : ColorTokens.Status.error)

            Button(config.isEnabled ? "Disable" : "Enable") {
                Task { await viewModel.toggleEnabled() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(viewModel.isToggling)

            if let classifier = config.classifierFunction {
                Text("Classifier: \(classifier)")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)
            }

            if config.isReconfigurationPending {
                Button("Apply Changes") {
                    Task { await viewModel.reconfigure() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(ColorTokens.Status.warning)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !viewModel.hasLoaded {
            initialState
        } else {
            VSplitView {
                poolsSection.frame(minHeight: LayoutTokens.SplitView.minimumPaneHeight)
                groupsSection.frame(minHeight: LayoutTokens.SplitView.minimumPaneHeight)
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
