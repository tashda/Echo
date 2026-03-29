import SwiftUI
import PostgresKit

struct PostgresOperatorsSection: View {
    @Bindable var viewModel: PostgresAdvancedObjectsViewModel
    @Environment(EnvironmentState.self) private var environmentState
    var onCreate: (() -> Void)?

    @State private var selection: Set<String> = []
    @State private var pendingDropID: String?
    @State private var pendingEdit: PendingEdit?

    var body: some View {
        Table(viewModel.operators, selection: $selection) {
            TableColumn("Name") { op in
                Text(op.name).font(TypographyTokens.Table.name)
            }
            .width(min: 50, ideal: 80)

            TableColumn("Left Type") { op in
                if let lt = op.leftType {
                    Text(lt).font(TypographyTokens.Table.category)
                        .foregroundStyle(ColorTokens.Text.secondary)
                } else {
                    Text("\u{2014}").foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .width(min: 80, ideal: 120)

            TableColumn("Right Type") { op in
                if let rt = op.rightType {
                    Text(rt).font(TypographyTokens.Table.category)
                        .foregroundStyle(ColorTokens.Text.secondary)
                } else {
                    Text("\u{2014}").foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .width(min: 80, ideal: 120)

            TableColumn("Result") { op in
                Text(op.resultType).font(TypographyTokens.Table.category)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 80, ideal: 120)

            TableColumn("Procedure") { op in
                Text(op.procedure).font(TypographyTokens.Table.secondaryName)
            }
            .width(min: 80, ideal: 140)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: String.self) { selection in
            contextMenuItems(selection: selection)
        } primaryAction: { _ in }
        .alert("Drop Operator?", isPresented: .init(
            get: { pendingDropID != nil },
            set: { if !$0 { pendingDropID = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingDropID = nil }
            Button("Drop", role: .destructive) {
                guard let id = pendingDropID else { return }
                pendingDropID = nil
                Task { await viewModel.dropOperator(id) }
            }
        } message: {
            Text("Are you sure you want to drop this operator? Dependent objects will also be dropped.")
        }
        .sheet(item: $pendingEdit) { edit in
            SingleFieldEditSheet(
                title: edit.title,
                fieldLabel: edit.fieldLabel,
                initialValue: edit.initialValue
            ) { newValue in
                switch edit.action {
                case .rename: break
                case .changeOwner: await viewModel.changeOperatorOwner(edit.objectName, newOwner: newValue)
                case .changeSchema: await viewModel.setOperatorSchema(edit.objectName, newSchema: newValue)
                }
            } onCancel: {
                pendingEdit = nil
            }
        }
    }

    @ViewBuilder
    private func contextMenuItems(selection: Set<String>) -> some View {
        if selection.isEmpty {
            Button { onCreate?() } label: {
                Label("New Operator", systemImage: "plus.forwardslash.minus")
            }
            Divider()
            Button { Task { await viewModel.loadCurrentSection() } } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        } else {
            Menu("Script as", systemImage: "scroll") {
                Button {
                    let scripts = selection.compactMap { id -> String? in
                        guard let op = viewModel.operators.first(where: { $0.id == id }) else { return nil }
                        let left = op.leftType ?? "NONE"
                        let right = op.rightType ?? "NONE"
                        let qualifiedName = ScriptingActions.pgQualifiedName(schema: op.schema, name: op.name)
                        return "DROP OPERATOR IF EXISTS \(qualifiedName)(\(left), \(right)) CASCADE;"
                    }
                    openScript(scripts.joined(separator: "\n"))
                } label: { Label("DROP", systemImage: "minus.square") }
            }
            Divider()
            if selection.count == 1, let id = selection.first {
                let op = viewModel.operators.first { $0.id == id }
                Button("Change Owner\u{2026}") {
                    pendingEdit = PendingEdit(action: .changeOwner, objectName: id, initialValue: "")
                }
                Button("Change Schema\u{2026}") {
                    pendingEdit = PendingEdit(action: .changeSchema, objectName: id, initialValue: op?.schema ?? "public")
                }
                Divider()
                Button(role: .destructive) { pendingDropID = id } label: {
                    Label("Drop Operator", systemImage: "trash")
                }
            } else {
                Button(role: .destructive) {
                    let scripts = selection.compactMap { id -> String? in
                        guard let op = viewModel.operators.first(where: { $0.id == id }) else { return nil }
                        let left = op.leftType ?? "NONE"
                        let right = op.rightType ?? "NONE"
                        let qualifiedName = ScriptingActions.pgQualifiedName(schema: op.schema, name: op.name)
                        return "DROP OPERATOR IF EXISTS \(qualifiedName)(\(left), \(right)) CASCADE;"
                    }
                    openScript(scripts.joined(separator: "\n"))
                } label: {
                    Label("Drop \(selection.count) Operators", systemImage: "trash")
                }
            }
        }
    }

    private func openScript(_ sql: String) {
        environmentState.openScriptTab(sql: sql, connectionID: viewModel.connectionID)
    }
}

extension PostgresOperatorInfo: @retroactive Identifiable {
    public var id: String { "\(schema).\(name)(\(leftType ?? "NONE"),\(rightType ?? "NONE"))" }
}
