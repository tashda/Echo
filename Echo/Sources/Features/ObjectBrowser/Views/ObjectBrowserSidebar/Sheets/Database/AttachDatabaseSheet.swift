import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AttachDatabaseSheet: View {
    let session: ConnectionSession
    let environmentState: EnvironmentState
    let onDismiss: () -> Void

    @State private var filePath = ""
    @State private var databaseName = ""
    @State private var isAttaching = false
    @State private var errorMessage: String?

    var canAttach: Bool {
        !filePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !databaseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isAttaching
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Database File") {
                    HStack {
                        TextField("", text: $filePath, prompt: Text("Path to .mdf file"))
                            .textFieldStyle(.roundedBorder)

                        Button("Browse...") {
                            browseForFile()
                        }
                    }
                }

                Section("Database Name") {
                    TextField("", text: $databaseName, prompt: Text("e.g. AdventureWorks"))
                        .textFieldStyle(.roundedBorder)
                }

                Section {
                    Label {
                        Text("Specify the primary data file (.mdf) path on the server. The database name will be used for the attached database.")
                            .font(TypographyTokens.formDescription)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    } icon: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            HStack {
                if let error = errorMessage {
                    Text(error)
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Status.error)
                        .lineLimit(2)
                }
                Spacer()
                if isAttaching {
                    ProgressView()
                        .controlSize(.small)
                }
                Button("Cancel") { onDismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                Button("Attach") {
                    Task { await attach() }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canAttach)
            }
            .padding(SpacingTokens.md)
        }
        .frame(minWidth: 480, minHeight: 280)
        .frame(idealWidth: 520, idealHeight: 320)
    }

    // MARK: - Validation & Helpers (Internal for testability)

    static func isAttachValid(filePath: String, databaseName: String, isAttaching: Bool) -> Bool {
        !filePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !databaseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isAttaching
    }

    static func databaseNameFromFilePath(_ url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
    }

    private func browseForFile() {
        let panel = NSOpenPanel()
        panel.title = "Select Database File"
        panel.allowedContentTypes = [.data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            filePath = url.path
            if databaseName.isEmpty {
                // Auto-fill database name from filename
                let filename = url.deletingPathExtension().lastPathComponent
                databaseName = filename
            }
        }
    }

    private func attach() async {
        isAttaching = true
        errorMessage = nil
        let handle = AppDirector.shared.activityEngine.begin("Attach \(databaseName)", connectionSessionID: session.id)

        do {
            let trimmedPath = filePath.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedName = databaseName.trimmingCharacters(in: .whitespacesAndNewlines)
            try await session.session.attachDatabase(name: trimmedName, files: [trimmedPath])
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
