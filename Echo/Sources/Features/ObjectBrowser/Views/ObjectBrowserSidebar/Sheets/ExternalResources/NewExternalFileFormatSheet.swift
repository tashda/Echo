import SwiftUI
import SQLServerKit

struct NewExternalFileFormatSheet: View {
    let databaseName: String
    let session: ConnectionSession
    let environmentState: EnvironmentState
    let onDismiss: () -> Void

    @State private var name = ""
    @State private var formatType: ExternalFileFormatType = .delimitedText
    @State private var fieldTerminator = "|"
    @State private var stringDelimiter = ""
    @State private var firstRowText = ""
    @State private var useTypeDefault = false
    @State private var isCreating = false
    @State private var errorMessage: String?

    var canCreate: Bool {
        Self.isCreateValid(name: name, isCreating: isCreating)
    }

    var body: some View {
        SheetLayout(
            title: "New External File Format",
            icon: "doc.badge.gearshape",
            subtitle: "Define a file format for external data sources.",
            primaryAction: "Create",
            canSubmit: canCreate,
            isSubmitting: isCreating,
            errorMessage: errorMessage,
            onSubmit: { await create() },
            onCancel: { onDismiss() }
        ) {
            Form {
                Section("File Format") {
                    TextField("Name", text: $name, prompt: Text("e.g. MyParquetFormat"))
                    Picker("Format Type", selection: $formatType) {
                        Text("Delimited Text").tag(ExternalFileFormatType.delimitedText)
                        Text("Parquet").tag(ExternalFileFormatType.parquet)
                        Text("ORC").tag(ExternalFileFormatType.orc)
                        Text("JSON").tag(ExternalFileFormatType.json)
                        Text("Delta").tag(ExternalFileFormatType.delta)
                    }
                }

                if formatType == .delimitedText {
                    Section("Delimited Text Options") {
                        TextField("Field Terminator", text: $fieldTerminator, prompt: Text("e.g. |"))
                        TextField("String Delimiter", text: $stringDelimiter, prompt: Text("e.g. \""))
                        TextField("First Row", text: $firstRowText, prompt: Text("e.g. 2"))
                        Toggle("Use Type Default", isOn: $useTypeDefault)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 460, minHeight: 300)
        .frame(idealWidth: 500, idealHeight: 360)
    }

    // MARK: - Validation (Internal for testability)

    static func isCreateValid(name: String, isCreating: Bool) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCreating
    }

    private func create() async {
        isCreating = true
        errorMessage = nil
        let handle = AppDirector.shared.activityEngine.begin(
            "Create external file format \(name)",
            connectionSessionID: session.id
        )

        do {
            guard let mssql = session.session as? MSSQLSession else { return }
            let trimmedFT = fieldTerminator.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedSD = stringDelimiter.trimmingCharacters(in: .whitespacesAndNewlines)
            let firstRow = Int(firstRowText.trimmingCharacters(in: .whitespacesAndNewlines))
            try await mssql.polyBase.createExternalFileFormat(
                database: databaseName,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                formatType: formatType,
                fieldTerminator: formatType == .delimitedText && !trimmedFT.isEmpty ? trimmedFT : nil,
                stringDelimiter: formatType == .delimitedText && !trimmedSD.isEmpty ? trimmedSD : nil,
                firstRow: formatType == .delimitedText ? firstRow : nil,
                useTypeDefault: formatType == .delimitedText ? useTypeDefault : nil
            )
            handle.succeed()
            environmentState.notificationEngine?.post(
                category: .maintenanceCompleted,
                message: "External file format \(name) created."
            )
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
            handle.fail(error.localizedDescription)
            isCreating = false
        }
    }
}
