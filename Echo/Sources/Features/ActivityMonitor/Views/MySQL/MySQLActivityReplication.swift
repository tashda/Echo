import SwiftUI
import MySQLKit

struct MySQLActivityReplication: View {
    @Bindable var viewModel: ActivityMonitorViewModel
    @State private var replicaStatus: MySQLReplicationStatus?
    @State private var primaryStatus: MySQLReplicationStatus?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .task { await load() }
    }

    private var toolbar: some View {
        HStack(spacing: SpacingTokens.sm) {
            Text("Replication Status")
                .font(TypographyTokens.headline)

            if let role = serverRole {
                Text(role)
                    .font(TypographyTokens.detail.weight(.medium))
                    .foregroundStyle(ColorTokens.Status.info)
            }

            Spacer()

            Button {
                Task { await load() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.sm)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && replicaStatus == nil && primaryStatus == nil {
            ActivitySectionLoadingView(
                title: "Replication",
                subtitle: "Checking replication configuration\u{2026}"
            )
        } else if !hasReplication {
            ContentUnavailableView {
                Label("Replication Not Configured", systemImage: "arrow.triangle.2.circlepath")
            } description: {
                Text("This server is not configured as a replica or primary with active replication.")
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                    if let replicaStatus {
                        replicaSection(replicaStatus)
                    }
                    if let primaryStatus {
                        primarySection(primaryStatus)
                    }
                }
                .padding(SpacingTokens.md)
            }
        }
    }

    private var hasReplication: Bool {
        let hasReplica = replicaStatus.map { !$0.rawValues.isEmpty } ?? false
        let hasPrimary = primaryStatus.map { !$0.rawValues.isEmpty } ?? false
        return hasReplica || hasPrimary
    }

    private var serverRole: String? {
        let hasReplica = replicaStatus.map { !$0.rawValues.isEmpty } ?? false
        let hasPrimary = primaryStatus.map { !$0.rawValues.isEmpty } ?? false
        if hasReplica && hasPrimary { return "Primary + Replica" }
        if hasReplica { return "Replica" }
        if hasPrimary { return "Primary" }
        return nil
    }

    private func replicaSection(_ status: MySQLReplicationStatus) -> some View {
        SectionContainer(
            title: "Replica Status",
            icon: "arrow.down.circle",
            info: "Status of inbound replication from the primary server."
        ) {
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                replicationGrid(status, keys: replicaKeys)
            }
            .padding(SpacingTokens.md)
        }
    }

    private func primarySection(_ status: MySQLReplicationStatus) -> some View {
        SectionContainer(
            title: "Primary Status",
            icon: "arrow.up.circle",
            info: "Binary log position and configuration for outbound replication."
        ) {
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                replicationGrid(status, keys: primaryKeys)
            }
            .padding(SpacingTokens.md)
        }
    }

    private func replicationGrid(_ status: MySQLReplicationStatus, keys: [String]) -> some View {
        let displayKeys = keys.filter { status.rawValues[$0] != nil }
        return Grid(alignment: .leading, horizontalSpacing: SpacingTokens.lg, verticalSpacing: SpacingTokens.sm) {
            ForEach(displayKeys, id: \.self) { key in
                GridRow {
                    Text(key.replacingOccurrences(of: "_", with: " "))
                        .font(TypographyTokens.formLabel)
                        .frame(minWidth: 200, alignment: .trailing)

                    let value = (status.rawValues[key] ?? nil) ?? "\u{2014}"
                    HStack(spacing: SpacingTokens.xs) {
                        if isThreadStatusKey(key) {
                            Circle()
                                .fill(value == "Yes" ? ColorTokens.Status.success : ColorTokens.Status.error)
                                .frame(width: 8, height: 8)
                        }
                        Text(value)
                            .font(TypographyTokens.Table.sql)
                            .textSelection(.enabled)
                            .foregroundStyle(isErrorValue(key: key, value: value) ? ColorTokens.Status.error : ColorTokens.Text.primary)
                    }
                }
            }
        }
    }

    private func isThreadStatusKey(_ key: String) -> Bool {
        key.contains("IO_Running") || key.contains("SQL_Running") ||
        key.contains("Slave_IO_Running") || key.contains("Slave_SQL_Running") ||
        key.contains("Replica_IO_Running") || key.contains("Replica_SQL_Running")
    }

    private func isErrorValue(key: String, value: String) -> Bool {
        if key.contains("Last_Error") || key.contains("Last_Errno") {
            return !value.isEmpty && value != "0" && value != "\u{2014}"
        }
        if isThreadStatusKey(key) {
            return value != "Yes"
        }
        return false
    }

    private var replicaKeys: [String] {
        [
            "Source_Host", "Source_Port", "Source_User",
            "Replica_IO_Running", "Replica_SQL_Running",
            "Slave_IO_Running", "Slave_SQL_Running",
            "Seconds_Behind_Source", "Seconds_Behind_Master",
            "Last_IO_Error", "Last_SQL_Error", "Last_IO_Errno", "Last_SQL_Errno",
            "Relay_Log_File", "Relay_Log_Pos",
            "Exec_Source_Log_Pos", "Exec_Master_Log_Pos",
            "Read_Source_Log_Pos", "Read_Master_Log_Pos",
            "Source_Log_File", "Master_Log_File",
            "Retrieved_Gtid_Set", "Executed_Gtid_Set"
        ]
    }

    private var primaryKeys: [String] {
        [
            "File", "Position",
            "Binlog_Do_DB", "Binlog_Ignore_DB",
            "Executed_Gtid_Set"
        ]
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let replica = viewModel.loadMySQLReplicaStatus()
            async let primary = viewModel.loadMySQLPrimaryStatus()
            replicaStatus = try await replica
            primaryStatus = try await primary
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

