import SwiftUI

/// A lightweight maintenance view for MySQL and SQLite connections.
/// Displays a list of runnable maintenance operations with results.
struct GenericMaintenanceView: View {
    @Bindable var viewModel: MaintenanceViewModel
    @Bindable var panelState: BottomPanelState
    @Environment(EnvironmentState.self) var environmentState

    @State private var operations: [MaintenanceOperation] = []
    @State private var runningOperationID: String?

    var body: some View {
        MaintenanceTabFrame(
            panelState: panelState,
            serverName: connectionText,
            isInitialized: viewModel.isInitialized,
            statusBubble: statusBubble
        ) {
            Text("Operations")
                .font(TypographyTokens.standard.weight(.medium))
        } content: {
            operationsList
        }
        .task {
            operations = Self.buildOperations(for: viewModel.databaseType)
            await loadDatabases()
            viewModel.isInitialized = true
        }
    }

    // MARK: - Operations List

    private var operationsList: some View {
        ScrollView {
            VStack(spacing: 0) {
                if viewModel.databaseType != .sqlite, viewModel.databaseList.count > 1 {
                    databasePicker
                }

                ForEach($operations) { $operation in
                    operationRow(operation: $operation)
                    if operation.id != operations.last?.id {
                        Divider().padding(.leading, SpacingTokens.lg)
                    }
                }

                if viewModel.databaseType == .sqlite {
                    Divider()
                        .padding(.vertical, SpacingTokens.sm)
                    SQLitePRAGMABrowserView(session: viewModel.session)
                }
            }
            .padding(SpacingTokens.md)
        }
    }

    private var databasePicker: some View {
        HStack {
            Text("Database")
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)
            Spacer()
            Picker("", selection: Binding(
                get: { viewModel.selectedDatabase ?? "" },
                set: { viewModel.selectedDatabase = $0.isEmpty ? nil : $0 }
            )) {
                ForEach(viewModel.databaseList, id: \.self) { db in
                    Text(db).tag(db)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: 200)
        }
        .padding(.bottom, SpacingTokens.md)
    }

    private func operationRow(operation: Binding<MaintenanceOperation>) -> some View {
        let op = operation.wrappedValue
        return HStack(alignment: .top, spacing: SpacingTokens.sm) {
            VStack(alignment: .leading, spacing: SpacingTokens.xs / 2) {
                Text(op.name)
                    .font(TypographyTokens.standard.weight(.medium))
                Text(op.description)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)

                if let result = op.lastResult {
                    resultBadge(result)
                        .padding(.top, SpacingTokens.xs / 2)
                }
            }

            Spacer()

            Button {
                Task { await runOperation(operation) }
            } label: {
                if runningOperationID == op.id {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 14, height: 14)
                } else {
                    Text("Run")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(runningOperationID != nil)
        }
        .padding(.vertical, SpacingTokens.sm)
    }

    private func resultBadge(_ result: MaintenanceOperationResult) -> some View {
        HStack(spacing: SpacingTokens.xs / 2) {
            Image(systemName: result.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(result.succeeded ? ColorTokens.Status.success : ColorTokens.Status.error)
            Text(result.message)
                .font(TypographyTokens.detail)
                .foregroundStyle(result.succeeded ? ColorTokens.Text.secondary : ColorTokens.Status.error)
        }
    }

    // MARK: - Execution

    private func runOperation(_ binding: Binding<MaintenanceOperation>) async {
        let operation = binding.wrappedValue
        runningOperationID = operation.id

        let handle = viewModel.activityEngine?.begin(
            "\(operation.name)",
            connectionSessionID: viewModel.connectionSessionID
        )

        let start = Date()
        do {
            let result = try await operation.action(viewModel.session, viewModel.selectedDatabase)
            binding.wrappedValue.lastResult = MaintenanceOperationResult(
                succeeded: result.succeeded,
                message: result.messages.joined(separator: "; ")
            )
            let duration = Date().timeIntervalSince(start)
            viewModel.logOperation(
                "\(operation.name): \(result.messages.joined(separator: "; "))",
                severity: result.succeeded ? .info : .error,
                duration: duration
            )
            if result.succeeded {
                handle?.succeed()
            } else {
                handle?.fail(result.messages.joined(separator: "; "))
            }
        } catch {
            binding.wrappedValue.lastResult = MaintenanceOperationResult(
                succeeded: false,
                message: error.localizedDescription
            )
            viewModel.logOperation(
                "\(operation.name) failed: \(error.localizedDescription)",
                severity: .error,
                duration: Date().timeIntervalSince(start)
            )
            handle?.fail(error.localizedDescription)
        }

        runningOperationID = nil
    }

    // MARK: - Helpers

    private var connectionText: String {
        let conn = viewModel.databaseType.displayName
        if let db = viewModel.selectedDatabase {
            return "\(conn) \u{2022} \(db)"
        }
        return conn
    }

    private var statusBubble: BottomPanelStatusBarConfiguration.StatusBubble? {
        guard let id = runningOperationID,
              let op = operations.first(where: { $0.id == id }) else { return nil }
        return .init(label: "Running \(op.name)", tint: .blue, isPulsing: true)
    }

    private func loadDatabases() async {
        guard let session = environmentState.sessionGroup.sessionForConnection(viewModel.connectionID) else { return }
        let databases = session.databaseStructure?.databases.map(\.name).sorted() ?? []
        viewModel.databaseList = databases
        if viewModel.selectedDatabase == nil, let first = databases.first {
            viewModel.selectedDatabase = first
        }
    }
}
