import SwiftUI
import PostgresKit

struct PostgresCastsSection: View {
    @Bindable var viewModel: PostgresAdvancedObjectsViewModel
    @Environment(EnvironmentState.self) private var environmentState
    var onCreate: (() -> Void)?

    @State private var selection: Set<String> = []
    @State private var pendingDropID: String?

    var body: some View {
        Table(viewModel.casts, selection: $selection) {
            TableColumn("Source Type") { cast in
                Text(cast.sourceType).font(TypographyTokens.Table.name)
            }
            .width(min: 100, ideal: 160)

            TableColumn("Target Type") { cast in
                Text(cast.targetType).font(TypographyTokens.Table.name)
            }
            .width(min: 100, ideal: 160)

            TableColumn("Function") { cast in
                if let fn = cast.function {
                    Text(fn).font(TypographyTokens.Table.secondaryName)
                } else {
                    Text("(binary coercible)")
                        .font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .width(min: 80, ideal: 140)

            TableColumn("Context") { cast in
                Text(cast.context)
                    .font(TypographyTokens.Table.category)
                    .foregroundStyle(contextColor(cast.context))
            }
            .width(min: 60, ideal: 100)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: String.self) { selection in
            contextMenuItems(selection: selection)
        } primaryAction: { _ in }
        .alert("Drop Cast?", isPresented: .init(
            get: { pendingDropID != nil },
            set: { if !$0 { pendingDropID = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingDropID = nil }
            Button("Drop", role: .destructive) {
                guard let id = pendingDropID else { return }
                pendingDropID = nil
                Task { await viewModel.dropCast(id) }
            }
        } message: {
            Text("Are you sure you want to drop this cast?")
        }
    }

    @ViewBuilder
    private func contextMenuItems(selection: Set<String>) -> some View {
        if selection.isEmpty {
            Button { onCreate?() } label: {
                Label("New Cast", systemImage: "arrow.right.arrow.left")
            }
            Divider()
            Button { Task { await viewModel.loadCurrentSection() } } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        } else {
            Menu("Script as", systemImage: "scroll") {
                Button {
                    let scripts = selection.compactMap { id -> String? in
                        guard let cast = viewModel.casts.first(where: { $0.id == id }) else { return nil }
                        return "DROP CAST IF EXISTS (\(cast.sourceType) AS \(cast.targetType));"
                    }
                    openScript(scripts.joined(separator: "\n"))
                } label: { Label("DROP", systemImage: "minus.square") }
            }
            Divider()
            if selection.count == 1, let id = selection.first {
                Button(role: .destructive) { pendingDropID = id } label: {
                    Label("Drop Cast", systemImage: "trash")
                }
            } else {
                Button(role: .destructive) {
                    let scripts = selection.compactMap { id -> String? in
                        guard let cast = viewModel.casts.first(where: { $0.id == id }) else { return nil }
                        return "DROP CAST IF EXISTS (\(cast.sourceType) AS \(cast.targetType));"
                    }
                    openScript(scripts.joined(separator: "\n"))
                } label: {
                    Label("Drop \(selection.count) Casts", systemImage: "trash")
                }
            }
        }
    }

    private func contextColor(_ context: String) -> Color {
        switch context {
        case "implicit": return ColorTokens.Status.success
        case "assignment": return ColorTokens.Status.info
        default: return ColorTokens.Text.secondary
        }
    }

    private func openScript(_ sql: String) {
        environmentState.openScriptTab(sql: sql, connectionID: viewModel.connectionID)
    }
}

extension PostgresCastInfo: @retroactive Identifiable {
    public var id: String { "\(sourceType)->\(targetType)" }
}
