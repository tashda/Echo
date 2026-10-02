import SwiftUI
import AppKit

/// Round MC: the form's toolbar. Cancel (✕, sheet) or Discard (inline, after an edit) on the left;
/// the title with the latest result under it; Test (stethoscope) and Save (✓) on the right, both
/// dimmed until they can work, their tooltip naming what is missing. A failed test opens a popover
/// with the server's own message and the log. Echo doesn't guess at a fix.
extension ConnectionEditorView {
    var editorToolbar: some View {
        HStack(spacing: SpacingTokens.xs) {
            leadingToolbarItem
                .frame(width: ConnectionEditorHeaderMetrics.sideWidth, alignment: .leading)

            VStack(spacing: SpacingTokens.micro) {
                Text(toolbarTitle)
                    .font(TypographyTokens.standard.weight(.semibold))
                    .lineLimit(1)
                toolbarSubtitle
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: SpacingTokens.xs) {
                // Nothing to test or save until the engine is chosen.
                if step == .form {
                    testButton
                    saveButton
                }
            }
            .frame(width: ConnectionEditorHeaderMetrics.sideWidth, alignment: .trailing)
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.top, SpacingTokens.sm)
        .padding(.bottom, SpacingTokens.xxs)
        .onChange(of: testResult?.isSuccessful) { _, succeeded in
            if succeeded == false { isShowingTestLog = true }
            notifyIfInBackground()
        }
    }

    // MARK: Leading

    @ViewBuilder
    private var leadingToolbarItem: some View {
        if presentation == .sheet {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .keyboardShortcut(.cancelAction)
            .help("Cancel")
            .accessibilityLabel("Cancel")
        } else if hasChanges, let onRevert {
            Button("Discard", action: onRevert)
                .buttonStyle(.glass)
                .help("Discard your changes")
        }
    }

    // MARK: Title

    private var toolbarTitle: String {
        if isQuickConnect { return "Quick Connect" }
        if originalConnection == nil { return "New Connection" }
        let trimmed = connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? (host.isEmpty ? "Connection" : host) : trimmed
    }

    @ViewBuilder
    private var toolbarSubtitle: some View {
        if isTestingConnection {
            Text("Testing \(host.trimmingCharacters(in: .whitespacesAndNewlines))…")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
                .lineLimit(1)
        } else if let result = testResult {
            Button { isShowingTestLog = true } label: {
                Text(result.isSuccessful ? successLine(result) : "Test failed")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(result.isSuccessful ? ColorTokens.Status.success : ColorTokens.Status.error)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .help("Show the log")
        } else if step == .form {
            Text(subtitleWithoutResult)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
                .lineLimit(1)
        }
    }

    private var subtitleWithoutResult: String {
        presentation == .inline && hasChanges ? "\(engineDescription) · Edited" : engineDescription
    }

    private func successLine(_ result: ConnectionTestResult) -> String {
        var parts = ["Connected"]
        if let version = result.serverVersion?.trimmingCharacters(in: .whitespacesAndNewlines), !version.isEmpty {
            parts.append(version)
        }
        if let time = result.responseTime {
            parts.append("\(Int((time * 1000).rounded())) ms")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: Test

    /// The first thing that stops a test or a save, in words, or nil when nothing does.
    var missingForTest: String? {
        if step == .chooseEngine { return "Choose a database first" }
        let order: [EditorField] = [.host, .port, .username, .domain, .password]
        return order.lazy.compactMap { validationIssues[$0] }.first
    }

    private var testButton: some View {
        Button(action: handleTestButton) {
            Group {
                if isTestingConnection {
                    ProgressView().controlSize(.small)
                } else if let result = testResult {
                    Image(systemName: result.isSuccessful ? "checkmark" : "xmark")
                        .foregroundStyle(result.isSuccessful ? ColorTokens.Status.success : ColorTokens.Status.error)
                } else {
                    Image(systemName: "stethoscope")
                }
            }
            .frame(width: ConnectionEditorHeaderMetrics.glyphSize, height: ConnectionEditorHeaderMetrics.glyphSize)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .disabled(!isTestingConnection && missingForTest != nil)
        .keyboardShortcut("t", modifiers: .command)
        .help(isTestingConnection ? "Cancel Test" : (missingForTest ?? "Test Connection (⌘T)"))
        .accessibilityLabel(isTestingConnection ? "Cancel Test" : "Test Connection")
        .popover(isPresented: $isShowingTestLog, arrowEdge: .bottom) { testResultPopover }
    }

    // MARK: Save

    /// What stops Save, or nil: something missing, or (editing) nothing changed.
    private var missingForSave: String? {
        if let missing = missingForTest { return missing }
        if presentation == .inline && originalConnection != nil && !hasChanges { return "Nothing to save" }
        return nil
    }

    private var saveButton: some View {
        Button(action: confirm) {
            Image(systemName: "checkmark")
                .frame(width: ConnectionEditorHeaderMetrics.glyphSize, height: ConnectionEditorHeaderMetrics.glyphSize)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .disabled(missingForSave != nil)
        .keyboardShortcut("s", modifiers: .command)
        .help(missingForSave ?? (presentation == .sheet && confirmAction == .saveAndConnect ? "Save and Connect" : "Save (⌘S)"))
        .accessibilityLabel("Save")
    }

    /// What ✓ does: the sheet's confirm action (Quick Connect without saving only connects), or
    /// a plain save inline.
    func confirm() {
        guard presentation == .sheet else {
            submit(.save)
            return
        }
        if isQuickConnect && !saveToConnections {
            submit(.connect)
        } else {
            submit(confirmAction)
        }
    }

    /// Return in a field: confirm when the form is complete, otherwise show what is missing and
    /// move focus to the first field with a problem.
    func confirmFromKeyboard() {
        if missingForSave == nil {
            confirm()
        } else if !(presentation == .inline && !hasChanges) {
            submitValidationOnly()
        }
    }

    private func submitValidationOnly() {
        let issues = validationIssues
        withAnimation { showsValidation = true }
        let order: [EditorField] = [.host, .port, .username, .domain, .password, .name]
        focusedField = order.first { issues[$0] != nil }
    }

    // MARK: Result and log

    private var testResultPopover: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            if let result = testResult {
                Label(result.isSuccessful ? "Connected" : "Test failed",
                      systemImage: result.isSuccessful ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(TypographyTokens.standard.weight(.semibold))
                    .foregroundStyle(result.isSuccessful ? ColorTokens.Status.success : ColorTokens.Status.error)
                if !result.isSuccessful {
                    // The server's own words, as they came back.
                    Text(result.message)
                        .font(TypographyTokens.detail.monospaced())
                        .textSelection(.enabled)
                        .padding(SpacingTokens.xs)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ColorTokens.Status.error.opacity(0.08), in: RoundedRectangle(cornerRadius: SpacingTokens.xs, style: .continuous))
                }
            }
            ScrollView {
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SpacingTokens.xs)
            }
            .frame(maxHeight: ConnectionEditorHeaderMetrics.logMaxHeight)
            .background(ColorTokens.Text.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: SpacingTokens.xs, style: .continuous))
            HStack {
                Spacer()
                Button("Copy Log", action: copyLog)
                    .controlSize(.small)
            }
        }
        .padding(SpacingTokens.sm)
        .frame(width: ConnectionEditorHeaderMetrics.popoverWidth)
    }

    private func copyLog() {
        let lines = testLogEntries.map { entry in
            "\(entry.timestamp.formatted(date: .omitted, time: .standard))  \(entry.message)"
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(lines.joined(separator: "\n"), forType: .string)
    }

    private func logEntryColor(_ kind: TestLogEntry.Kind) -> Color {
        switch kind {
        case .info: ColorTokens.Text.secondary
        case .success: ColorTokens.Status.success
        case .error: ColorTokens.Status.error
        }
    }

    /// A test that ends while Echo is in the background says so as a notification.
    private func notifyIfInBackground() {
        guard let result = testResult, !(NSApp?.isActive ?? true) else { return }
        let name = toolbarTitle
        environmentState.notificationEngine?.post(
            category: result.isSuccessful ? .connectionConnected : .connectionFailed,
            message: result.isSuccessful ? "Test passed: \(name) · \(successLine(result))" : "Test failed: \(name). \(result.message)"
        )
    }
}

enum ConnectionEditorHeaderMetrics {
    /// Wide enough for Discard on the left and the two circles on the right.
    static let sideWidth: CGFloat = 84
    static let glyphSize: CGFloat = 16
    static let chipSize: CGFloat = 40
    static let portWidth: CGFloat = 56
    static let popoverWidth: CGFloat = 340
    static let logMaxHeight: CGFloat = 180
}
