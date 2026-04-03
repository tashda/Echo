import SwiftUI
import SQLServerKit

struct ResourceGovernorView: View {
    @Bindable var viewModel: ResourceGovernorViewModel

    @State private var showNewPoolSheet = false
    @State private var showNewGroupSheet = false
    @State private var pendingDropPool: String?
    @State private var pendingDropGroup: String?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            
            VSplitView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Resource Pools")
                        .font(TypographyTokens.headline)
                        .padding(SpacingTokens.sm)
                    poolsTable
                }
                .frame(minHeight: 150)
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("Workload Groups")
                        .font(TypographyTokens.headline)
                        .padding(SpacingTokens.sm)
                    groupsTable
                }
                .frame(minHeight: 150)
            }
        }
        .background(ColorTokens.Background.primary)
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
        HStack(spacing: SpacingTokens.md) {
            Button {
                viewModel.refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isRefreshing)
            
            if viewModel.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }
            
            Divider().frame(height: 16)
            
            if let config = viewModel.configuration {
                HStack(spacing: SpacingTokens.xs) {
                    Image(systemName: config.isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(config.isEnabled ? ColorTokens.Status.success : ColorTokens.Status.error)
                    Text(config.isEnabled ? "Enabled" : "Disabled")
                        .font(TypographyTokens.detail)
                }

                Button(config.isEnabled ? "Disable" : "Enable") {
                    Task { await viewModel.toggleEnabled() }
                }
                .controlSize(.small)
                .disabled(viewModel.isToggling)

                if let classifier = config.classifierFunction {
                    Text("Classifier: \(classifier)")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(.secondary)
                }

                if config.isReconfigurationPending {
                    Button("Apply Changes") {
                        Task { await viewModel.reconfigure() }
                    }
                    .controlSize(.small)
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Status.error)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Background.secondary)
    }
    
    private var poolsTable: some View {
        Table(viewModel.pools, selection: $viewModel.selectedPoolID) {
            TableColumn("Name") { p in
                Text(p.name)
                    .font(TypographyTokens.Table.name)
            }
            TableColumn("Min/Max CPU %") { p in
                Text("\(p.minCpuPercent) / \(p.maxCpuPercent)")
                    .font(TypographyTokens.Table.percentage)
            }
            TableColumn("Memory %") { p in
                Text("\(p.minMemoryPercent) / \(p.maxMemoryPercent)")
                    .font(TypographyTokens.Table.percentage)
            }
            TableColumn("Sessions") { p in
                Text(p.stats.map { "\($0.activeSessionCount)" } ?? "-")
                    .font(TypographyTokens.Table.numeric)
            }
            .width(60)
            TableColumn("Usage") { p in
                if let stats = p.stats {
                    usageBar(value: stats.cpuUsagePercent / 100.0)
                } else {
                    Text("-")
                }
            }
            .width(100)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: Int32.self) { selection in
            if let id = selection.first, let pool = viewModel.pools.first(where: { $0.poolId == id }) {
                let isBuiltIn = pool.name == "internal" || pool.name == "default"
                Button(role: .destructive) {
                    pendingDropPool = pool.name
                } label: {
                    Label("Drop Pool", systemImage: "trash")
                }
                .disabled(isBuiltIn)
            } else {
                Button { showNewPoolSheet = true } label: {
                    Label("New Pool", systemImage: "cpu")
                }
            }
        } primaryAction: { _ in }
    }
    
    private var groupsTable: some View {
        Table(viewModel.groups, selection: $viewModel.selectedGroupID) {
            TableColumn("Name") { g in
                Text(g.name)
                    .font(TypographyTokens.Table.name)
            }
            TableColumn("Pool") { g in
                Text(g.poolName)
                    .font(TypographyTokens.Table.secondaryName)
            }
            TableColumn("Importance") { g in
                Text(g.importance)
                    .font(TypographyTokens.Table.category)
            }
            TableColumn("Requests") { g in
                Text(g.stats.map { "\($0.activeRequestCount)" } ?? "-")
                    .font(TypographyTokens.Table.numeric)
            }
            .width(60)
            TableColumn("Queued") { g in
                Text(g.stats.map { "\($0.queuedRequestCount)" } ?? "0")
                    .font(TypographyTokens.Table.numeric)
                    .foregroundStyle((g.stats?.queuedRequestCount ?? 0) > 0 ? ColorTokens.Status.warning : .secondary)
            }
            .width(60)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: Int32.self) { selection in
            if let id = selection.first, let group = viewModel.groups.first(where: { $0.groupId == id }) {
                let isBuiltIn = group.name == "internal" || group.name == "default"
                Button(role: .destructive) {
                    pendingDropGroup = group.name
                } label: {
                    Label("Drop Group", systemImage: "trash")
                }
                .disabled(isBuiltIn)
            } else {
                Button { showNewGroupSheet = true } label: {
                    Label("New Workload Group", systemImage: "person.3")
                }
            }
        } primaryAction: { _ in }
    }
    
    private func usageBar(value: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.2))
                Capsule()
                    .fill(value > 0.8 ? ColorTokens.Status.error : Color.accentColor)
                    .frame(width: geo.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 8)
        .padding(.vertical, 4)
    }
}
