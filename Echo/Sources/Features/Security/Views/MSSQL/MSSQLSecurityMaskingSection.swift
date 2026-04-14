import SwiftUI
import SQLServerKit

struct MSSQLSecurityMaskingSection: View {
    @Bindable var viewModel: DatabaseSecurityViewModel
    var onNewMask: () -> Void
    @Environment(EnvironmentState.self) private var environmentState

    @State private var sortOrder = [KeyPathComparator(\MaskedColumnInfo.schema)]
    @State private var showDropAlert = false
    @State private var pendingDropItem: MaskedColumnInfo?

    private var sortedColumns: [MaskedColumnInfo] {
        viewModel.maskedColumns.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedColumns, selection: $viewModel.selectedMaskedColumnID, sortOrder: $sortOrder) {
            TableColumn("Schema", value: \.schema) { item in
                Text(item.schema)
                    .font(TypographyTokens.Table.name)
            }
            .width(min: 60, ideal: 100)

            TableColumn("Table", value: \.table) { item in
                Text(item.table)
                    .font(TypographyTokens.Table.name)
            }
            .width(min: 80, ideal: 140)

            TableColumn("Column", value: \.column) { item in
                Text(item.column)
                    .font(TypographyTokens.Table.secondaryName)
            }
            .width(min: 80, ideal: 140)

            TableColumn("Masking Function", value: \.maskingFunction) { item in
                Text(item.maskingFunction)
                    .font(TypographyTokens.Table.category)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 100, ideal: 180)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .contextMenu(forSelectionType: String.self) { selection in
            if let id = selection.first,
               let item = viewModel.maskedColumns.first(where: { $0.id == id }) {
                Menu("Script as", systemImage: "scroll") {
                    Button { scriptAddMask(item) } label: {
                        Label("ADD MASKED", systemImage: "plus.square")
                    }
                    Button { scriptDropMask(item) } label: {
                        Label("DROP MASKED", systemImage: "minus.square")
                    }
                }

                Divider()

                Button(role: .destructive) {
                    pendingDropItem = item
                    showDropAlert = true
                } label: {
                    Label("Drop Mask", systemImage: "trash")
                }
            } else {
                Button {
                    Task { await viewModel.loadCurrentSection() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button { onNewMask() } label: {
                    Label("New Mask", systemImage: "theatermask.and.paintbrush")
                }
            }
        } primaryAction: { _ in }
        .alert("Drop Mask?", isPresented: $showDropAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Drop", role: .destructive) {
                if let item = pendingDropItem {
                    Task { await viewModel.dropMask(schema: item.schema, table: item.table, column: item.column) }
                }
            }
        } message: {
            Text("Are you sure you want to remove the mask from \(pendingDropItem?.id ?? "")? This action cannot be undone.")
        }
    }

    private func scriptAddMask(_ item: MaskedColumnInfo) {
        let s = escapeID(item.schema)
        let t = escapeID(item.table)
        let c = escapeID(item.column)
        let fn = item.maskingFunction
        openScriptTab(sql: "ALTER TABLE \(s).\(t) ALTER COLUMN \(c) ADD MASKED WITH (FUNCTION = '\(fn)');\nGO")
    }

    private func scriptDropMask(_ item: MaskedColumnInfo) {
        let s = escapeID(item.schema)
        let t = escapeID(item.table)
        let c = escapeID(item.column)
        openScriptTab(sql: "ALTER TABLE \(s).\(t) ALTER COLUMN \(c) DROP MASKED;\nGO")
    }

    private func escapeID(_ name: String) -> String {
        "[\(name.replacingOccurrences(of: "]", with: "]]"))]"
    }

    private func openScriptTab(sql: String) {
        if let session = environmentState.sessionGroup.sessionForConnection(viewModel.connectionID) {
            environmentState.openQueryTab(for: session, presetQuery: sql)
        }
    }
}
