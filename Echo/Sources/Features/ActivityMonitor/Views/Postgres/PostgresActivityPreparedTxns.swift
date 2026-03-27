import SwiftUI
import PostgresKit

struct PostgresActivityPreparedTxns: View {
    let connectionID: UUID
    @Environment(EnvironmentState.self) private var environmentState

    @State private var transactions: [PostgresPreparedTransaction] = []
    @State private var selection: Set<String> = []
    @State private var isLoading = false
    @State private var pendingCommitGID: String?
    @State private var pendingRollbackGID: String?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            table
        }
        .task { await loadTransactions() }
        .alert("Commit Prepared Transaction?", isPresented: .init(
            get: { pendingCommitGID != nil },
            set: { if !$0 { pendingCommitGID = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingCommitGID = nil }
            Button("Commit") {
                guard let gid = pendingCommitGID else { return }
                pendingCommitGID = nil
                Task { await commitPrepared(gid: gid) }
            }
        } message: {
            if let gid = pendingCommitGID {
                Text("Commit prepared transaction '\(gid)'? This cannot be undone.")
            }
        }
        .alert("Rollback Prepared Transaction?", isPresented: .init(
            get: { pendingRollbackGID != nil },
            set: { if !$0 { pendingRollbackGID = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingRollbackGID = nil }
            Button("Rollback", role: .destructive) {
                guard let gid = pendingRollbackGID else { return }
                pendingRollbackGID = nil
                Task { await rollbackPrepared(gid: gid) }
            }
        } message: {
            if let gid = pendingRollbackGID {
                Text("Rollback prepared transaction '\(gid)'? All changes will be lost.")
            }
        }
    }

    private var toolbar: some View {
        HStack {
            Spacer()
            if isLoading { ProgressView().controlSize(.small) }
            Button { Task { await loadTransactions() } } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
    }

    private var table: some View {
        Table(transactions, selection: $selection) {
            TableColumn("Transaction ID") { txn in
                Text(txn.transactionID).font(TypographyTokens.Table.numeric)
            }
            .width(min: 80, ideal: 120)

            TableColumn("GID") { txn in
                Text(txn.gid).font(TypographyTokens.Table.name)
            }
            .width(min: 100, ideal: 180)

            TableColumn("Prepared") { txn in
                Text(txn.prepared).font(TypographyTokens.Table.date)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 120, ideal: 160)

            TableColumn("Owner") { txn in
                Text(txn.owner).font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 80, ideal: 100)

            TableColumn("Database") { txn in
                Text(txn.database).font(TypographyTokens.Table.secondaryName)
            }
            .width(min: 80, ideal: 120)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .contextMenu(forSelectionType: String.self) { sel in
            if let gid = sel.first {
                Button { pendingCommitGID = gid } label: {
                    Label("Commit Prepared", systemImage: "checkmark.circle")
                }
                Button(role: .destructive) { pendingRollbackGID = gid } label: {
                    Label("Rollback Prepared", systemImage: "xmark.circle")
                }
            }
        } primaryAction: { _ in }
        .overlay {
            if transactions.isEmpty && !isLoading {
                ContentUnavailableView {
                    Label("No Prepared Transactions", systemImage: "tray")
                } description: {
                    Text("There are no pending two-phase transactions.")
                }
            }
        }
    }

    private func loadTransactions() async {
        guard let session = environmentState.sessionGroup.sessionForConnection(connectionID),
              let pg = session.session as? PostgresSession else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            transactions = try await pg.client.introspection.listPreparedTransactions()
        } catch {
            transactions = []
        }
    }

    private func commitPrepared(gid: String) async {
        guard let session = environmentState.sessionGroup.sessionForConnection(connectionID),
              let pg = session.session as? PostgresSession else { return }
        do {
            try await pg.client.admin.commitPrepared(gid: gid)
            await loadTransactions()
        } catch {
            // Error handled silently; transaction remains in list
        }
    }

    private func rollbackPrepared(gid: String) async {
        guard let session = environmentState.sessionGroup.sessionForConnection(connectionID),
              let pg = session.session as? PostgresSession else { return }
        do {
            try await pg.client.admin.rollbackPrepared(gid: gid)
            await loadTransactions()
        } catch {
            // Error handled silently; transaction remains in list
        }
    }
}

extension PostgresPreparedTransaction: @retroactive Identifiable {
    public var id: String { gid }
}
