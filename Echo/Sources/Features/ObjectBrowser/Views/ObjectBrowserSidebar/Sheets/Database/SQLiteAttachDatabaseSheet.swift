import SwiftUI
import AppKit

struct SQLiteAttachDatabaseSheet: View {
    let session: ConnectionSession
    let environmentState: EnvironmentState
    let onDismiss: () -> Void

    @State private var filePath = ""
    @State private var alias = ""
    @State private var isAttaching = false
    @State private var errorMessage: String?

    var canAttach: Bool {
        !filePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !alias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && alias.lowercased() != "main"
            && !isAttaching
    }

    var body: some View {
        SheetLayout(
            title: "Attach Database",
            icon: "plus.circle",
            subtitle: "Attach an external SQLite database file.",
            primaryAction: "Attach",
            canSubmit: canAttach,
            isSubmitting: isAttaching,
            errorMessage: errorMessage,
            onSubmit: { await attach() },
            onCancel: { onDismiss() }
        ) {
            Form {
                Section("Database File") {
                    HStack {
                        TextField("", text: $filePath, prompt: Text("/path/to/database.sqlite"))
                            .textFieldStyle(.roundedBorder)

                        Button("Browse") {
                            browseForFile()
                        }
                    }
                }

                Section {
                    TextField("", text: $alias, prompt: Text("e.g. secondary"))
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("Alias")
                } footer: {
                    Text("The alias is used to reference tables in the attached database, e.g. SELECT * FROM alias.table_name")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 480, minHeight: 280)
        .frame(idealWidth: 520, idealHeight: 320)
    }

    // MARK: - Validation

    static func isAttachValid(filePath: String, alias: String, isAttaching: Bool) -> Bool {
        !filePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !alias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && alias.lowercased() != "main"
            && !isAttaching
    }

    static func aliasFromFilePath(_ url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
    }

    private func browseForFile() {
        let panel = NSOpenPanel()
        panel.title = "Select SQLite Database File"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            filePath = url.path
            if alias.isEmpty {
                alias = Self.aliasFromFilePath(url)
            }
        }
    }

    private func attach() async {
        isAttaching = true
        errorMessage = nil
        let trimmedAlias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        let handle = AppDirector.shared.activityEngine.begin("Attach \(trimmedAlias)", connectionSessionID: session.id)

        do {
            guard let sqliteSession = session.session as? SQLiteSession else {
                throw DatabaseError.queryError("Not a SQLite session")
            }
            let trimmedPath = filePath.trimmingCharacters(in: .whitespacesAndNewlines)
            try await sqliteSession.attachSQLiteDatabase(path: trimmedPath, alias: trimmedAlias)
            handle.succeed()
            await environmentState.refreshDatabaseStructure(for: session.id)
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
            handle.fail(error.localizedDescription)
            isAttaching = false
        }
    }
}
