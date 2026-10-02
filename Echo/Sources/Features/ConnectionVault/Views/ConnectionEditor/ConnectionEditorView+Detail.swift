import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// The connection form (Design/05-components › Connections, round MC): a toolbar with Cancel or
/// Discard, the title and the latest result, Test and Save; then, for a new connection, the
/// engine step; then the form: icon and name, Server, Sign in, Security and Behaviour.
extension ConnectionEditorView {
    var detailView: some View {
        VStack(spacing: SpacingTokens.none) {
            editorToolbar

            if step == .chooseEngine {
                engineStep
                    .transition(.opacity)
            } else {
                form
                    .transition(.opacity)
            }
        }
    }

    private var form: some View {
        Form {
            if saveToConnections {
                identitySection
            }
            serverSection
            if selectedDatabaseType != .sqlite {
                authenticationSection
            }
            securitySection
            behaviourSection
            if isQuickConnect {
                Section {
                    Toggle("Save to Connections", isOn: $saveToConnections.animation())
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        // Return in any field saves, or shows what is missing (round MC: Save stays dimmed until
        // the form is complete; Return moves focus to the first missing field).
        .onSubmit(confirmFromKeyboard)
        .onAppear { refreshKeyNeedsPassword() }
        .onChange(of: sslCertPath) { _, _ in refreshKeyNeedsPassword() }
        .onChange(of: sslKeyPath) { _, _ in refreshKeyNeedsPassword() }
        .onChange(of: selectedDatabaseType) { _, _ in refreshKeyNeedsPassword() }
    }

    // MARK: - Icon and name

    private var identitySection: some View {
        Section {
            HStack(spacing: SpacingTokens.sm) {
                Button { isShowingAppearance = true } label: {
                    ServerRailMark(
                        monogram: ServerRailMonogram.make(from: appearanceName),
                        glyph: railGlyph,
                        color: appearanceColor,
                        weight: .bold,
                        size: ConnectionEditorHeaderMetrics.chipSize
                    )
                    .background(appearanceColor.opacity(ServerAppearanceMetrics.previewTintOpacity), in: Circle())
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Choose the server's colour and symbol")
                .accessibilityLabel("Appearance")
                .popover(isPresented: $isShowingAppearance, arrowEdge: .bottom) {
                    ServerAppearanceControls(name: appearanceName, colorHex: $colorHex, glyph: $railGlyph)
                        .padding(SpacingTokens.md)
                        .frame(width: ServerAppearanceMetrics.popoverWidth)
                }

                VStack(alignment: .leading, spacing: SpacingTokens.nano) {
                    TextField("", text: $connectionName, prompt: Text(namePrompt))
                        .labelsHidden()
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.leading)
                        .font(TypographyTokens.title3.weight(.semibold))
                        .focused($focusedField, equals: .name)
                    Text("Shows as \(railLabel) in the server trail")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
            .padding(.vertical, SpacingTokens.xxs)
        }
    }

    private var namePrompt: String {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedHost.isEmpty ? "Name" : trimmedHost
    }

    private var railLabel: String {
        switch railGlyph {
        case .symbol?: return "its symbol"
        case .emoji(let value)?: return value
        case nil: return ServerRailMonogram.make(from: appearanceName)
        }
    }

    private var appearanceColor: Color {
        ServerColorPalette.swiftUIColor(forStored: colorHex) ?? .accentColor
    }

    /// The name the appearance takes its letters from: the name, else the server.
    var appearanceName: String {
        let trimmed = connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? host : trimmed
    }

    // MARK: - Server

    private var serverSection: some View {
        Section("Server") {
            engineRow

            if selectedDatabaseType == .sqlite {
                InsetRow("File") {
                    HStack(spacing: SpacingTokens.xs) {
                        TextField("", text: $host, prompt: Text("~/Data/app.sqlite"))
                            .focused($focusedField, equals: .host)
                        Button("Choose…") { browseForSQLiteFile() }
                            .controlSize(.small)
                    }
                }
                validationRow(for: .host)
            } else {
                InsetRow("Server") {
                    HStack(spacing: SpacingTokens.xs) {
                        TextField("", text: $host, prompt: Text("Host, or paste a connection URL"))
                            .focused($focusedField, equals: .host)
                        Rectangle()
                            .fill(ColorTokens.Separator.primary)
                            .frame(width: 1, height: SpacingTokens.sm2)
                        TextField("", value: $port, format: .number.grouping(.never), prompt: Text(verbatim: "\(selectedDatabaseType.defaultPort)"))
                            .multilineTextAlignment(.trailing)
                            .frame(width: ConnectionEditorHeaderMetrics.portWidth)
                            .focused($focusedField, equals: .port)
                    }
                }
                validationRow(for: .host)
                validationRow(for: .port)
                additionalServerRows
                InsetRow("Database") {
                    TextField("", text: $database, prompt: Text("Default"))
                }
            }
        }
    }

    /// The engine, shown and never changed once chosen (round MC).
    private var engineRow: some View {
        LabeledContent("Engine") {
            HStack(spacing: SpacingTokens.xxs2) {
                Image(selectedDatabaseType.iconName)
                    .foregroundStyle(ColorTokens.Text.primary)
                Text(engineDescription)
                    .foregroundStyle(ColorTokens.Text.primary)
                if originalConnection != nil {
                    Image(systemName: "lock.fill")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .help(originalConnection != nil ? "A saved connection keeps its engine." : "")
        }
    }

    /// "PostgreSQL", or "PostgreSQL 16.4" once Echo has connected to a saved connection.
    var engineDescription: String {
        let name = selectedDatabaseType.shortDisplayName
        guard let version = originalConnection?.serverVersion?.trimmingCharacters(in: .whitespacesAndNewlines),
              !version.isEmpty else { return name }
        return version.localizedCaseInsensitiveContains(name) ? version : "\(name) \(version)"
    }

    /// An inline message under a field, shown after Return on an incomplete form.
    @ViewBuilder
    func validationRow(for field: EditorField) -> some View {
        if showsValidation, let message = validationIssues[field] {
            Label(message, systemImage: "exclamationmark.circle.fill")
                .font(TypographyTokens.formDescription)
                .foregroundStyle(ColorTokens.Status.error)
                .listRowSeparator(.hidden)
        }
    }
}

extension DatabaseType {
    /// Names short enough for tiles and rows.
    var shortDisplayName: String {
        self == .microsoftSQL ? "SQL Server" : displayName
    }
}

extension MSSQLEncryptionMode {
    /// The mode's name alone, for the segmented picker and the summary.
    var shortName: String {
        switch self {
        case .optional: "Optional"
        case .mandatory: "Mandatory"
        case .strict: "Strict"
        }
    }
}

extension TLSMode {
    var shortName: String { description.components(separatedBy: " - ").first ?? description }
}
