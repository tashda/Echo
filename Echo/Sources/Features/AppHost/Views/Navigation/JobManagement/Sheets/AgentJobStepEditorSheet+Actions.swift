import SwiftUI
import SQLServerKit

extension AgentJobStepEditorSheet {
    var draft: Draft {
        Draft(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            subsystem: subsystem,
            database: database.isEmpty ? nil : database,
            command: command.trimmingCharacters(in: .whitespacesAndNewlines),
            proxyName: proxyName.isEmpty ? nil : proxyName,
            outputFile: outputFile.isEmpty ? nil : outputFile,
            outcome: outcome
        )
    }

    func save() {
        guard canSave else { return }
        isSaving = true
        Task {
            let error = await onSave(draft)
            isSaving = false
            if let error {
                let lowered = error.localizedLowercase
                nameHasError = lowered.contains("step_name") || lowered.contains("already exists")
                errorMessage = error
            }
        }
    }

    /// CE2: checks the T-SQL without running it; a failing line is marked in the editor.
    func parse() {
        let text = command
        parseState = .parsing
        Task {
            do {
                if let issue = try await onParse(text) {
                    parseState = .issue(line: issue.line, message: issue.message)
                } else {
                    parseState = .parsed
                }
            } catch {
                parseState = .failed(error.localizedDescription)
            }
        }
    }
}
