import SwiftUI
import SQLServerKit

struct NewMaskSheet: View {
    let session: ConnectionSession
    let database: String?
    let onComplete: () -> Void

    @State private var tables: [TableMetadata] = []
    @State private var columns: [ColumnMetadata] = []
    @State private var selectedTable: String?
    @State private var selectedColumn: String?
    @State private var maskType: MaskType = .defaultMask
    @State private var randomStart = "0"
    @State private var randomEnd = "100"
    @State private var partialPrefix = "1"
    @State private var partialPadding = "XXXX"
    @State private var partialSuffix = "0"
    @State private var datetimePart = "Y"
    @State private var isSubmitting = false
    @State private var isLoadingTables = false
    @State private var errorMessage: String?

    enum MaskType: String, CaseIterable {
        case defaultMask = "Default"
        case email = "Email"
        case random = "Random"
        case partial = "Partial"
        case datetime = "DateTime"
    }

    private var isFormValid: Bool {
        selectedTable != nil && selectedColumn != nil && !isSubmitting
    }

    private var maskFunction: MaskFunction {
        switch maskType {
        case .defaultMask: return .defaultMask
        case .email: return .email
        case .random: return .random(start: Int(randomStart) ?? 0, end: Int(randomEnd) ?? 100)
        case .partial: return .partial(prefix: Int(partialPrefix) ?? 1, padding: partialPadding, suffix: Int(partialSuffix) ?? 0)
        case .datetime: return .datetime(part: datetimePart)
        }
    }

    private var selectedSchema: String {
        guard let tableName = selectedTable,
              let table = tables.first(where: { $0.name == tableName }) else { return "dbo" }
        return table.schema
    }

    var body: some View {
        SheetLayout(
            title: "Add Data Mask",
            icon: "theatermask.and.paintbrush",
            subtitle: "Apply a dynamic data mask to a column.",
            primaryAction: "Create",
            canSubmit: isFormValid,
            isSubmitting: isSubmitting,
            errorMessage: errorMessage,
            onSubmit: { await submit() },
            onCancel: { onComplete() }
        ) {
            Form {
                Section("Target Column") {
                    PropertyRow(title: "Table") {
                        Picker("", selection: $selectedTable) {
                            Text("Select a table").tag(nil as String?)
                            ForEach(tables, id: \.name) { table in
                                Text("\(table.schema).\(table.name)").tag(table.name as String?)
                            }
                        }
                        .labelsHidden()
                    }

                    PropertyRow(title: "Column") {
                        Picker("", selection: $selectedColumn) {
                            Text("Select a column").tag(nil as String?)
                            ForEach(columns, id: \.name) { col in
                                Text("\(col.name) (\(col.typeName))").tag(col.name as String?)
                            }
                        }
                        .labelsHidden()
                        .disabled(selectedTable == nil)
                    }
                }

                Section("Mask Function") {
                    PropertyRow(title: "Type") {
                        Picker("", selection: $maskType) {
                            ForEach(MaskType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .labelsHidden()
                    }

                    if maskType == .random {
                        PropertyRow(title: "Start") {
                            TextField("", text: $randomStart, prompt: Text("0"))
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                        }
                        PropertyRow(title: "End") {
                            TextField("", text: $randomEnd, prompt: Text("100"))
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    if maskType == .partial {
                        PropertyRow(title: "Prefix Length") {
                            TextField("", text: $partialPrefix, prompt: Text("1"))
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                        }
                        PropertyRow(title: "Padding") {
                            TextField("", text: $partialPadding, prompt: Text("XXXX"))
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                        }
                        PropertyRow(title: "Suffix Length") {
                            TextField("", text: $partialSuffix, prompt: Text("0"))
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    if maskType == .datetime {
                        PropertyRow(title: "Part") {
                            Picker("", selection: $datetimePart) {
                                Text("Year").tag("Y")
                                Text("Month").tag("M")
                                Text("Day").tag("D")
                                Text("Hour").tag("h")
                                Text("Minute").tag("m")
                                Text("Second").tag("s")
                            }
                            .labelsHidden()
                        }
                    }
                }

                Section("Preview") {
                    Text(maskFunction.sqlExpression)
                        .font(TypographyTokens.code)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 440, idealWidth: 480, minHeight: 380)
        .task { await loadTables() }
        .onChange(of: selectedTable) { _, _ in
            selectedColumn = nil
            Task { await loadColumns() }
        }
    }

    private func loadTables() async {
        guard let mssql = session.session as? MSSQLSession else { return }
        isLoadingTables = true
        defer { isLoadingTables = false }
        do {
            if let db = database {
                _ = try? await session.session.sessionForDatabase(db)
            }
            tables = try await mssql.metadata.listTables(database: database)
        } catch {
            tables = []
        }
    }

    private func loadColumns() async {
        guard let mssql = session.session as? MSSQLSession,
              let tableName = selectedTable else {
            columns = []
            return
        }
        do {
            columns = try await mssql.metadata.listColumns(database: database, schema: selectedSchema, table: tableName)
        } catch {
            columns = []
        }
    }

    private func submit() async {
        guard let mssql = session.session as? MSSQLSession,
              let tableName = selectedTable,
              let columnName = selectedColumn else { return }

        isSubmitting = true
        errorMessage = nil

        do {
            if let db = database {
                _ = try? await session.session.sessionForDatabase(db)
            }
            try await mssql.security.addMask(schema: selectedSchema, table: tableName, column: columnName, function: maskFunction)
            onComplete()
        } catch {
            isSubmitting = false
            errorMessage = error.localizedDescription
        }
    }
}
