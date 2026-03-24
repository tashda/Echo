import SwiftUI
import SQLServerKit

struct NewServerAuditSheet: View {
    let session: ConnectionSession
    let onComplete: () -> Void

    @State private var auditName = ""
    @State private var destination: AuditDestination = .applicationLog
    @State private var filePath = ""
    @State private var maxFileSize = ""
    @State private var maxRolloverFiles = ""
    @State private var reserveDiskSpace = false
    @State private var queueDelay = "1000"
    @State private var onFailure: AuditOnFailure = .continueOperation
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        let name = auditName.trimmingCharacters(in: .whitespacesAndNewlines)
        let validFile = destination != .file || !filePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return !name.isEmpty && validFile && !isSubmitting
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("General") {
                    PropertyRow(title: "Audit Name") {
                        TextField("", text: $auditName, prompt: Text("e.g. PCI_Audit"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }

                    PropertyRow(title: "Destination") {
                        Picker("", selection: $destination) {
                            Text("Application Log").tag(AuditDestination.applicationLog)
                            Text("Security Log").tag(AuditDestination.securityLog)
                            Text("File").tag(AuditDestination.file)
                        }
                        .labelsHidden()
                    }
                }

                if destination == .file {
                    Section("File Settings") {
                        PropertyRow(title: "File Path") {
                            TextField("", text: $filePath, prompt: Text("e.g. /var/opt/mssql/audit/"))
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                        }

                        PropertyRow(title: "Max File Size (MB)") {
                            TextField("", text: $maxFileSize, prompt: Text("e.g. 100"))
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                        }

                        PropertyRow(title: "Max Rollover Files") {
                            TextField("", text: $maxRolloverFiles, prompt: Text("e.g. 10"))
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                        }

                        PropertyRow(title: "Reserve Disk Space") {
                            Toggle("", isOn: $reserveDiskSpace)
                                .labelsHidden()
                        }
                    }
                }

                Section("Options") {
                    PropertyRow(title: "Queue Delay (ms)") {
                        TextField("", text: $queueDelay, prompt: Text("1000"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }

                    PropertyRow(title: "On Failure") {
                        Picker("", selection: $onFailure) {
                            Text("Continue").tag(AuditOnFailure.continueOperation)
                            Text("Shutdown Server").tag(AuditOnFailure.shutdownServer)
                            Text("Fail Operation").tag(AuditOnFailure.failOperation)
                        }
                        .labelsHidden()
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            HStack(spacing: SpacingTokens.sm) {
                if let error = errorMessage {
                    Text(error)
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Status.error)
                        .lineLimit(1)
                }

                Spacer()

                Button("Cancel") { onComplete() }
                    .keyboardShortcut(.cancelAction)

                Button("Create") { Task { await submit() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isFormValid)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, SpacingTokens.md2)
            .padding(.vertical, SpacingTokens.sm2)
            .background(.bar)
        }
        .frame(minWidth: 440, idealWidth: 480, minHeight: 340)
        .navigationTitle("New Server Audit")
    }

    private func submit() async {
        guard let mssql = session.session as? MSSQLSession else {
            errorMessage = "Not connected to SQL Server"
            return
        }

        let name = auditName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        do {
            let options = ServerAuditOptions(
                queueDelay: Int(queueDelay),
                onFailure: onFailure,
                filePath: destination == .file ? filePath.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                maxFileSize: Int(maxFileSize),
                maxRolloverFiles: Int(maxRolloverFiles),
                reserveDiskSpace: destination == .file ? reserveDiskSpace : nil
            )
            try await mssql.audit.createServerAudit(name: name, destination: destination, options: options)
            onComplete()
        } catch {
            isSubmitting = false
            errorMessage = error.localizedDescription
        }
    }
}
