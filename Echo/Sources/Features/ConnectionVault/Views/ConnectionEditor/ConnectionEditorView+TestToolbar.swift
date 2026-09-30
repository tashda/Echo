import SwiftUI

// MARK: - ConnectionEditorView footer: test result by the buttons (CR4)

extension ConnectionEditorView {

    var toolbarView: some View {
        HStack(spacing: SpacingTokens.xs) {
            Button(isTestingConnection ? "Cancel Test" : "Test") {
                if isTestingConnection || isFormValid { handleTestButton() } else { submitValidationOnly() }
            }
            testStatus
            Spacer(minLength: SpacingTokens.xs)
            actionButtons
        }
        .padding(presentation == .sheet ? SpacingTokens.md2 : SpacingTokens.sm)
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch presentation {
        case .sheet:
            Button("Cancel", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
            if isQuickConnect {
                Button(saveToConnections ? "Save and Connect" : "Connect") {
                    submit(saveToConnections ? .saveAndConnect : .connect)
                }
                .keyboardShortcut(.defaultAction)
            } else {
                Button("Save") { submit(.save) }
                Button("Save and Connect") { submit(.saveAndConnect) }
                    .keyboardShortcut(.defaultAction)
            }
        case .inline:
            if let onRevert {
                Button("Revert", action: onRevert)
            }
            Button("Connect") { submit(.saveAndConnect) }
            Button("Save") { submit(.save) }
                .keyboardShortcut(.defaultAction)
        }
    }

    /// One line: a spinner while testing, then the result in plain words. The full log is one
    /// click away.
    @ViewBuilder
    private var testStatus: some View {
        if isTestingConnection {
            HStack(spacing: SpacingTokens.xxs2) {
                ProgressView().controlSize(.small)
                Text("Testing").foregroundStyle(ColorTokens.Text.secondary)
            }
            .font(TypographyTokens.formDescription)
        } else if let entry = testLogEntries.last {
            Button { isShowingTestLog = true } label: {
                Label(entry.message, systemImage: entry.kind == .error ? "xmark.circle.fill" : entry.kind == .success ? "checkmark.circle.fill" : "info.circle")
                    .foregroundStyle(logEntryColor(entry.kind))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .buttonStyle(.plain)
            .font(TypographyTokens.formDescription)
            .help("Show the test log")
            .popover(isPresented: $isShowingTestLog, arrowEdge: .top) { testTranscript }
            if let fix = testResult?.fix, testResult?.isSuccessful == false {
                Button(fix.title) { apply(fix) }
                    .controlSize(.small)
            }
        }
    }

    /// Applies the fix a failed test offered, then tests again (round 22, TE1).
    private func apply(_ fix: ConnectionTestFix) {
        switch fix {
        case .trustCertificate:
            trustServerCertificate = true
        case .hostNameInCertificate(let name):
            hostNameInCertificate = name
        case .allowLegacyTLS:
            allowLegacyTLS = true
        }
        startConnectionTest()
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
        }
        .frame(minWidth: LayoutTokens.FloatingSurface.mediumWidth, alignment: .leading)
        .padding(SpacingTokens.sm)
    }

    private func logEntryColor(_ kind: TestLogEntry.Kind) -> Color {
        switch kind {
        case .info: ColorTokens.Text.secondary
        case .success: ColorTokens.Status.success
        case .error: ColorTokens.Status.error
        }
    }

    /// Test with missing fields shows the same inline messages as Save.
    private func submitValidationOnly() {
        let issues = validationIssues
        withAnimation { showsValidation = true }
        let order: [EditorField] = [.host, .port, .username, .domain, .password, .name]
        focusedField = order.first { issues[$0] != nil }
    }
}
