import SwiftUI

// MARK: - ConnectionEditorView Test Connection & Toolbar

extension ConnectionEditorView {

    var testConnectionSection: some View {
        Section {
            PropertyRow(title: "Test") {
                Button(action: handleTestButton) {
                    HStack(spacing: SpacingTokens.xxs2) {
                        if isTestingConnection {
                            ProgressView().controlSize(.small)
                            Text("Cancel")
                        } else {
                            Image(systemName: "link.badge.plus")
                            Text("Test Connection")
                        }
                    }
                }
                .buttonStyle(.bordered)
                .disabled(!isTestingConnection && !isFormValid)
            }

            if !testLogEntries.isEmpty || isTestingConnection {
                testTranscript
            }
        }
    }

    private var testTranscript: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
            ForEach(testLogEntries) { entry in
                HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xxs2) {
                    Text(entry.timestamp, format: .dateTime.hour().minute().second())
                        .foregroundStyle(ColorTokens.Text.tertiary)
                    Text(entry.message)
                        .foregroundStyle(logEntryColor(entry.kind))
                        .textSelection(.enabled)
                }
                .font(TypographyTokens.detail.monospaced())
            }

            if isTestingConnection {
                HStack(spacing: SpacingTokens.xxs2) {
                    ProgressView().controlSize(.mini)
                    Text("Waiting for response...")
                        .font(TypographyTokens.detail.monospaced())
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SpacingTokens.xs)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: SpacingTokens.xxs))
    }

    private func logEntryColor(_ kind: TestLogEntry.Kind) -> Color {
        switch kind {
        case .info: ColorTokens.Text.secondary
        case .success: ColorTokens.Status.success
        case .error: ColorTokens.Status.error
        }
    }

    var toolbarView: some View {
        HStack {
            Spacer()

            Button("Cancel", role: .cancel) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            if isQuickConnect {
                Button("Save & Connect") {
                    handleSave(action: .saveAndConnect)
                }
                .disabled(!isFormValid)

                Button("Connect") {
                    handleSave(action: .connect)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isFormValid)
            } else {
                Button("Save") {
                    handleSave(action: .save)
                }
                .disabled(!isFormValid)

                Button("Save & Connect") {
                    handleSave(action: .saveAndConnect)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isFormValid)
            }
        }
        .padding(SpacingTokens.md2)
    }
}
