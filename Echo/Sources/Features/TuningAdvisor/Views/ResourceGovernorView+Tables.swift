import SQLServerKit
import SwiftUI

extension ResourceGovernorView {
    var poolsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Resource Pools")
                .font(TypographyTokens.headline)
                .padding(SpacingTokens.sm)

            if viewModel.pools.isEmpty {
                TabContentUnavailableView("No Resource Pools", systemImage: "cpu") {
                    Text("No Resource Governor pools are configured.")
                } actions: {
                    Button("New Resource Pool") { showNewPoolSheet = true }
                        .buttonStyle(.bordered)
                }
            } else {
                poolsTable
            }
        }
    }

    var groupsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Workload Groups")
                .font(TypographyTokens.headline)
                .padding(SpacingTokens.sm)

            if viewModel.groups.isEmpty {
                TabContentUnavailableView("No Workload Groups", systemImage: "person.3") {
                    Text("No Resource Governor workload groups are configured.")
                } actions: {
                    Button("New Workload Group") { showNewGroupSheet = true }
                        .buttonStyle(.bordered)
                }
            } else {
                groupsTable
            }
        }
    }

    private var poolsTable: some View {
        Table(viewModel.pools, selection: $viewModel.selectedPoolID) {
            TableColumn("Name") { pool in
                Text(pool.name).font(TypographyTokens.Table.name)
            }
            TableColumn("Min/Max CPU %") { pool in
                Text("\(pool.minCpuPercent) / \(pool.maxCpuPercent)").font(TypographyTokens.Table.percentage)
            }
            TableColumn("Memory %") { pool in
                Text("\(pool.minMemoryPercent) / \(pool.maxMemoryPercent)").font(TypographyTokens.Table.percentage)
            }
            TableColumn("Sessions") { pool in
                Text(pool.stats.map { "\($0.activeSessionCount)" } ?? "—")
                    .font(TypographyTokens.Table.numeric)
            }
            .width(60)
            TableColumn("Usage") { pool in
                if let stats = pool.stats {
                    usageBar(value: stats.cpuUsagePercent / 100.0)
                } else {
                    Text("—").foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .width(100)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .contextMenu(forSelectionType: Int32.self) { selection in
            if let id = selection.first,
               let pool = viewModel.pools.first(where: { $0.poolId == id }) {
                Button(role: .destructive) { pendingDropPool = pool.name } label: {
                    Label("Drop Pool", systemImage: "trash")
                }
                .disabled(pool.name == "internal" || pool.name == "default")
            } else {
                Button {
                    showNewPoolSheet = true
                } label: {
                    Label("New Resource Pool", systemImage: "cpu")
                }
            }
        } primaryAction: { _ in }
    }

    private var groupsTable: some View {
        Table(viewModel.groups, selection: $viewModel.selectedGroupID) {
            TableColumn("Name") { group in
                Text(group.name).font(TypographyTokens.Table.name)
            }
            TableColumn("Pool") { group in
                Text(group.poolName).font(TypographyTokens.Table.secondaryName)
            }
            TableColumn("Importance") { group in
                Text(group.importance).font(TypographyTokens.Table.category)
            }
            TableColumn("Requests") { group in
                Text(group.stats.map { "\($0.activeRequestCount)" } ?? "—")
                    .font(TypographyTokens.Table.numeric)
            }
            .width(60)
            TableColumn("Queued") { group in
                Text(group.stats.map { "\($0.queuedRequestCount)" } ?? "0")
                    .font(TypographyTokens.Table.numeric)
                    .foregroundStyle(
                        (group.stats?.queuedRequestCount ?? 0) > 0
                            ? ColorTokens.Status.warning
                            : ColorTokens.Text.secondary
                    )
            }
            .width(60)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .contextMenu(forSelectionType: Int32.self) { selection in
            if let id = selection.first,
               let group = viewModel.groups.first(where: { $0.groupId == id }) {
                Button(role: .destructive) { pendingDropGroup = group.name } label: {
                    Label("Drop Group", systemImage: "trash")
                }
                .disabled(group.name == "internal" || group.name == "default")
            } else {
                Button {
                    showNewGroupSheet = true
                } label: {
                    Label("New Workload Group", systemImage: "person.3")
                }
            }
        } primaryAction: { _ in }
    }

    private func usageBar(value: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(ColorTokens.Text.secondary.opacity(0.2))
                Capsule()
                    .fill(value > 0.8 ? ColorTokens.Status.error : ColorTokens.accent)
                    .frame(width: geometry.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: SpacingTokens.xs)
        .padding(.vertical, SpacingTokens.xxxs)
    }
}
