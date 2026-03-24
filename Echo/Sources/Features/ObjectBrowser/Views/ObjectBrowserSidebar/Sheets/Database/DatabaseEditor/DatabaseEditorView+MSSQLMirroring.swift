import SwiftUI
import SQLServerKit

// MARK: - Mirroring Page

extension DatabaseEditorView {

    @ViewBuilder
    func mssqlMirroringPage() -> some View {
        if let status = viewModel.mirroringStatus, status.isConfigured {
            Section("Status") {
                PropertyRow(title: "State") {
                    Text(status.stateDescription ?? "Unknown")
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                PropertyRow(title: "Role") {
                    Text(status.roleDescription ?? "Unknown")
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                PropertyRow(title: "Safety Level") {
                    Text(status.safetyLevelDescription ?? "Unknown")
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

            Section("Partner") {
                PropertyRow(title: "Partner Address") {
                    Text(status.partnerName.isEmpty ? "Not set" : status.partnerName)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .textSelection(.enabled)
                }
                PropertyRow(title: "Partner Instance") {
                    Text(status.partnerInstance.isEmpty ? "Not set" : status.partnerInstance)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .textSelection(.enabled)
                }
            }

            Section("Witness") {
                PropertyRow(title: "Witness Address") {
                    Text(status.witnessName.isEmpty ? "Not configured" : status.witnessName)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .textSelection(.enabled)
                }
                PropertyRow(title: "Witness State") {
                    Text(status.witnessStateDescription.isEmpty ? "N/A" : status.witnessStateDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

            if let timeout = status.connectionTimeout {
                Section("Connection") {
                    PropertyRow(title: "Connection Timeout") {
                        Text("\(timeout) seconds")
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                    if let redo = status.redoQueue {
                        PropertyRow(title: "Redo Queue") {
                            Text("\(redo) records")
                                .foregroundStyle(ColorTokens.Text.secondary)
                        }
                    }
                }
            }
        }
    }
}
