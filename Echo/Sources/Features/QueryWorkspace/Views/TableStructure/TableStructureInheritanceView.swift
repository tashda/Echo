import SwiftUI
import PostgresKit

struct TableStructureInheritanceView: View {
    @Bindable var viewModel: TableStructureEditorViewModel

    @State private var parents: [PostgresInheritanceInfo] = []
    @State private var children: [PostgresInheritanceInfo] = []
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                Spacer()
                ProgressView("Loading inheritance\u{2026}")
                    .controlSize(.small)
                Spacer()
            } else if parents.isEmpty && children.isEmpty {
                ContentUnavailableView {
                    Label("No Inheritance", systemImage: "arrow.triangle.branch")
                } description: {
                    Text("This table does not inherit from or have child tables.")
                }
            } else {
                Form {
                    if !parents.isEmpty {
                        Section("Inherits From") {
                            ForEach(parents, id: \.tableName) { parent in
                                PropertyRow(title: parent.tableName) {
                                    Text(parent.schemaName)
                                        .font(TypographyTokens.detail)
                                        .foregroundStyle(ColorTokens.Text.secondary)
                                }
                            }
                        }
                    }

                    if !children.isEmpty {
                        Section("Child Tables") {
                            ForEach(children, id: \.tableName) { child in
                                PropertyRow(title: child.tableName) {
                                    Text(child.schemaName)
                                        .font(TypographyTokens.detail)
                                        .foregroundStyle(ColorTokens.Text.secondary)
                                }
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
            }
        }
        .task { await loadInheritance() }
    }

    private func loadInheritance() async {
        guard let pg = viewModel.session as? PostgresSession else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            parents = try await pg.client.metadata.listInheritanceParents(schema: viewModel.schemaName, table: viewModel.tableName)
            children = try await pg.client.metadata.listInheritanceChildren(schema: viewModel.schemaName, table: viewModel.tableName)
        } catch {
            viewModel.lastError = error.localizedDescription
        }
        viewModel.inheritanceAvailable = !parents.isEmpty || !children.isEmpty
    }
}
