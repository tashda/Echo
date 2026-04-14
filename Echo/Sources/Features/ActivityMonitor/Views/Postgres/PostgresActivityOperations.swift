import SwiftUI
import PostgresWire

struct PostgresActivityOperations: View {
    let operations: [PostgresOperationProgress]
    @Binding var selection: Set<PostgresOperationProgress.ID>
    let onCancel: (Int) -> Void
    var onDoubleClick: (() -> Void)?

    @State private var showCancelAlert = false
    @State private var pendingCancelPID: Int?

    var body: some View {
        operationsTable
            .overlay {
                if operations.isEmpty {
                    ContentUnavailableView {
                        Label("No Active Operations", systemImage: "gearshape.arrow.triangle.2.circlepath")
                    } description: {
                        Text("Long-running operations like VACUUM, ANALYZE, CREATE INDEX, and COPY will appear here with progress.")
                    }
                }
            }
    }

    private var operationsTable: some View {
        Table(operations, selection: $selection) {
            TableColumn("PID") {
                Text("\($0.pid)")
                    .font(TypographyTokens.Table.numeric)
            }.width(min: 50, ideal: 60)

            TableColumn("Operation") {
                Text($0.operation)
                    .font(TypographyTokens.Table.category)
            }.width(min: 80, ideal: 100)

            TableColumn("Phase") {
                Text($0.phase)
                    .font(TypographyTokens.Table.category)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }.width(min: 120, ideal: 180)

            TableColumn("Progress") {
                OperationProgressCell(percent: $0.progressPercent)
            }.width(min: 100, ideal: 140)

            TableColumn("Database") {
                Text($0.databaseName ?? "\u{2014}")
                    .font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle($0.databaseName == nil ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
            }.width(min: 80, ideal: 100)

            TableColumn("Object") {
                Text($0.relation ?? "\u{2014}")
                    .font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle($0.relation == nil ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
                    .lineLimit(1)
            }.width(min: 100, ideal: 160)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .contextMenu(forSelectionType: PostgresOperationProgress.ID.self) { selection in
            if let id = selection.first, let op = operations.first(where: { $0.id == id }) {
                Button(role: .destructive) {
                    pendingCancelPID = Int(op.pid)
                    showCancelAlert = true
                } label: {
                    Label("Cancel Operation", systemImage: "xmark.circle")
                }
            }
        } primaryAction: { _ in
            onDoubleClick?()
        }
        .alert("Cancel Operation?", isPresented: $showCancelAlert) {
            Button("Keep Running", role: .cancel) { pendingCancelPID = nil }
            Button("Cancel Operation", role: .destructive) {
                guard let pid = pendingCancelPID else { return }
                pendingCancelPID = nil
                onCancel(pid)
            }
        } message: {
            Text("Are you sure you want to cancel this operation? Partial progress may be lost.")
        }
    }
}

private struct OperationProgressCell: View {
    let percent: Double?

    var body: some View {
        if let percent {
            HStack(spacing: SpacingTokens.xxs) {
                ProgressView(value: percent, total: 100)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 80)
                Text("\(Int(percent))%")
                    .font(TypographyTokens.compact.monospacedDigit())
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        } else {
            Text("Indeterminate")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
    }
}
