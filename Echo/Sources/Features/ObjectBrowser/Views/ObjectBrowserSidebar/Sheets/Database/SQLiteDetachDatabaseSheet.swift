import SwiftUI

struct SQLiteDetachDatabaseSheet: View {
    let databaseName: String
    let session: ConnectionSession
    let environmentState: EnvironmentState
    let onDismiss: () -> Void

    @State private var isDetaching = false
    @State private var errorMessage: String?

    var body: some View {
        SheetLayout(
            title: "Detach Database",
            icon: "eject",
            subtitle: "Detach an attached database.",
            primaryAction: "Detach",
            canSubmit: canDetach && !isDetaching,
            isSubmitting: isDetaching,
            errorMessage: errorMessage,
            onSubmit: { await detach() },
            onCancel: { onDismiss() }
        ) {
            Form {
                Section {
                    PropertyRow(title: "Database") {
                        Text(databaseName)
                            .foregroundStyle(ColorTokens.Text.primary)
                            .fontWeight(.medium)
                    }
                }

                if !canDetach {
                    Section {
                        Label {
                            Text("The \"main\" database cannot be detached.")
                                .font(TypographyTokens.formDescription)
                                .foregroundStyle(ColorTokens.Status.error)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(ColorTokens.Status.warning)
                        }
                    }
                } else {
                    Section {
                        Label {
                            Text("This will disconnect the attached database. The file will not be deleted.")
                                .font(TypographyTokens.formDescription)
                                .foregroundStyle(ColorTokens.Text.secondary)
                        } icon: {
                            Image(systemName: "info.circle")
                                .foregroundStyle(ColorTokens.Text.tertiary)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 400, minHeight: 220)
        .frame(idealWidth: 440, idealHeight: 260)
    }

    /// The "main" and "temp" databases cannot be detached.
    var canDetach: Bool {
        let name = databaseName.lowercased()
        return name != "main" && name != "temp"
    }

    static func canDetachDatabase(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower != "main" && lower != "temp"
    }

    private func detach() async {
        isDetaching = true
        errorMessage = nil
        let handle = AppDirector.shared.activityEngine.begin("Detach \(databaseName)", connectionSessionID: session.id)

        do {
            guard let sqliteSession = session.session as? SQLiteSession else {
                throw DatabaseError.queryError("Not a SQLite session")
            }
            try await sqliteSession.detachSQLiteDatabase(alias: databaseName)
            handle.succeed()
            await environmentState.refreshDatabaseStructure(for: session.id)
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
            handle.fail(error.localizedDescription)
            isDetaching = false
        }
    }
}
