import SwiftUI
import SQLServerKit

/// Sheet for creating or editing a SQL Server Agent alert.
struct AgentAlertEditorSheet: View {
    @State var alertName: String
    @State var severity: Int
    @State var messageId: Int
    @State var databaseName: String
    @State var eventDescriptionKeyword: String
    @State var enabled: Bool

    let databaseNames: [String]
    let isEditing: Bool
    let onSave: (String, Int, Int, String?, String?, Bool) async -> String?
    let onCancel: () -> Void

    @State private var errorMessage: String?
    @State private var isSaving = false

    init(
        alert: SQLServerAgentAlertInfo? = nil,
        databaseNames: [String],
        onSave: @escaping (String, Int, Int, String?, String?, Bool) async -> String?,
        onCancel: @escaping () -> Void
    ) {
        self._alertName = State(initialValue: alert?.name ?? "")
        self._severity = State(initialValue: alert?.severity ?? 0)
        self._messageId = State(initialValue: alert?.messageId ?? 0)
        self._databaseName = State(initialValue: alert?.databaseName ?? "")
        self._eventDescriptionKeyword = State(initialValue: alert?.eventDescriptionKeyword ?? "")
        self._enabled = State(initialValue: alert?.enabled ?? true)
        self.databaseNames = databaseNames
        self.isEditing = alert != nil
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private var isValid: Bool {
        !alertName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && (severity > 0 || messageId > 0)
        && !isSaving
    }

    var body: some View {
        SheetLayout(
            title: isEditing ? "Edit Alert" : "New Alert",
            primaryAction: isEditing ? "Save" : "Create",
            canSubmit: isValid,
            isSubmitting: isSaving,
            errorMessage: errorMessage,
            onSubmit: { await performSave() },
            onCancel: { onCancel() }
        ) {
            Form {
                Section("General") {
                    TextField("Name", text: $alertName, prompt: Text("e.g. Severity 17+ Alert"))
                    Toggle("Enabled", isOn: $enabled)
                        .toggleStyle(.switch)
                }

                Section("Condition") {
                    Picker("Severity", selection: $severity) {
                        Text("None").tag(0)
                        ForEach(1...25, id: \.self) { s in
                            Text("Severity \(s)").tag(s)
                        }
                    }
                    .onChange(of: severity) { _, newValue in
                        if newValue > 0 { messageId = 0 }
                    }

                    Stepper("Message ID: \(messageId)", value: $messageId, in: 0...2_147_483_647)
                        .onChange(of: messageId) { _, newValue in
                            if newValue > 0 { severity = 0 }
                        }
                }

                Section("Filter") {
                    Picker("Database", selection: $databaseName) {
                        Text("All databases").tag("")
                        ForEach(databaseNames, id: \.self) { db in
                            Text(db).tag(db)
                        }
                    }

                    TextField("Event description keyword", text: $eventDescriptionKeyword, prompt: Text("e.g. deadlock"))
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 440, idealWidth: 480, minHeight: 380)
    }

    private func performSave() async {
        isSaving = true
        let db: String? = databaseName.isEmpty ? nil : databaseName
        let keyword: String? = eventDescriptionKeyword.isEmpty ? nil : eventDescriptionKeyword
        let error = await onSave(
            alertName.trimmingCharacters(in: .whitespacesAndNewlines),
            severity,
            messageId,
            db,
            keyword,
            enabled
        )
        isSaving = false
        errorMessage = error
    }
}
