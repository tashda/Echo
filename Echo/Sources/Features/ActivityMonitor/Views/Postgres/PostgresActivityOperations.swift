import SwiftUI
import PostgresWire

struct PostgresActivityOperations: View {
    let operations: [PostgresOperationProgress]
    @Binding var selection: Set<PostgresOperationProgress.ID>
    let onCancel: (Int) -> Void
    var onDoubleClick: (() -> Void)?

    var body: some View {
        if operations.isEmpty {
            EmptyStatePlaceholder(
                icon: "gearshape.arrow.triangle.2.circlepath",
                title: "No Active Operations",
                subtitle: "Long-running operations like VACUUM, ANALYZE, CREATE INDEX, and COPY will appear here with progress"
            )
        } else {
            operationsTable
        }
    }

    private var operationsTable: some View {
        Table(operations, selection: $selection) {
            TableColumn("PID") {
                Text("\($0.pid)")
                    .font(TypographyTokens.detail.monospacedDigit())
            }.width(min: 50, ideal: 60)

            TableColumn("Operation") {
                Text($0.operation)
                    .font(TypographyTokens.detail.weight(.medium))
            }.width(min: 80, ideal: 100)

            TableColumn("Phase") {
                Text($0.phase)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }.width(min: 120, ideal: 180)

            TableColumn("Progress") {
                OperationProgressCell(percent: $0.progressPercent)
            }.width(min: 100, ideal: 140)

            TableColumn("Database") {
                Text($0.databaseName ?? "\u{2014}")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }.width(min: 80, ideal: 100)

            TableColumn("Object") {
                Text($0.relation ?? "\u{2014}")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)
            }.width(min: 100, ideal: 160)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: PostgresOperationProgress.ID.self) { selection in
            if let id = selection.first, let op = operations.first(where: { $0.id == id }) {
                Button("Cancel Operation") {
                    onCancel(Int(op.pid))
                }
            }
        } primaryAction: { _ in
            onDoubleClick?()
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
