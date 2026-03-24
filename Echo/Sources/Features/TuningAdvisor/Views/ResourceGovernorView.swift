import SwiftUI
import SQLServerKit

struct ResourceGovernorView: View {
    @Bindable var viewModel: ResourceGovernorViewModel
    
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
                        .foregroundStyle(config.isEnabled ? .green : .red)
                    Text(config.isEnabled ? "Enabled" : "Disabled")
                        .font(TypographyTokens.detail)
                }
                
                if let classifier = config.classifierFunction {
                    Text("Classifier: \(classifier)")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(.secondary)
                }
                
                if config.isReconfigurationPending {
                    Text("Pending Reconfigure")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(.orange)
                }
            }
            
            Spacer()
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Background.secondary)
    }
    
    private var poolsTable: some View {
        Table(viewModel.pools, selection: $viewModel.selectedPoolID) {
            TableColumn("Name", value: \.name)
            TableColumn("Min/Max CPU %") { p in
                Text("\(p.minCpuPercent) / \(p.maxCpuPercent)")
            }
            TableColumn("Memory %") { p in
                Text("\(p.minMemoryPercent) / \(p.maxMemoryPercent)")
            }
            TableColumn("Sessions") { p in
                Text(p.stats.map { "\($0.activeSessionCount)" } ?? "-")
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
    }
    
    private var groupsTable: some View {
        Table(viewModel.groups, selection: $viewModel.selectedGroupID) {
            TableColumn("Name", value: \.name)
            TableColumn("Pool", value: \.poolName)
            TableColumn("Importance", value: \.importance)
            TableColumn("Requests") { g in
                Text(g.stats.map { "\($0.activeRequestCount)" } ?? "-")
            }
            .width(60)
            TableColumn("Queued") { g in
                Text(g.stats.map { "\($0.queuedRequestCount)" } ?? "0")
                    .foregroundStyle((g.stats?.queuedRequestCount ?? 0) > 0 ? .orange : .secondary)
            }
            .width(60)
        }
    }
    
    private func usageBar(value: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.2))
                Capsule()
                    .fill(value > 0.8 ? Color.red : Color.accentColor)
                    .frame(width: geo.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 8)
        .padding(.vertical, 4)
    }
}
