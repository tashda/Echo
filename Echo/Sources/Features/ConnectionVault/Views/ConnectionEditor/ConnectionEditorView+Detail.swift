import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// The short connection form (Design/05-components › Connections): engine, server and sign in
/// first; Security and timeouts in one disclosure; name, folder and colour only when saving.
extension ConnectionEditorView {
    var detailView: some View {
        VStack(spacing: SpacingTokens.none) {
            Form {
                serverSection
                if selectedDatabaseType != .sqlite {
                    authenticationSection
                }
                optionsSection
                savedAsSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .onAppear { refreshKeyNeedsPassword() }
            .onChange(of: sslCertPath) { _, _ in refreshKeyNeedsPassword() }
            .onChange(of: sslKeyPath) { _, _ in refreshKeyNeedsPassword() }
            .onChange(of: selectedDatabaseType) { _, _ in refreshKeyNeedsPassword() }

            Divider()

            toolbarView
        }
    }

    private var formTitle: String {
        if isQuickConnect { return "Quick Connect" }
        return originalConnection == nil ? "New Connection" : (connectionName.isEmpty ? "Connection" : connectionName)
    }

    private var serverSection: some View {
        Section {
            Picker("Database", selection: $selectedDatabaseType) {
                ForEach(DatabaseType.allCases, id: \.self) { type in
                    Text(type.shortDisplayName).tag(type)
                }
            }
            .pickerStyle(.segmented)

            if selectedDatabaseType == .sqlite {
                PropertyRow(title: "Database File") {
                    HStack(spacing: SpacingTokens.xs) {
                        TextField("", text: $host, prompt: Text("~/Data/app.sqlite"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .host)
                        Button("Choose") { browseForSQLiteFile() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
                validationRow(for: .host)
            } else {
                PropertyRow(title: "Server") {
                    HStack(spacing: SpacingTokens.xxs2) {
                        TextField("", text: $host, prompt: Text("db.example.com or a connection URL"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .host)
                        Text(":").foregroundStyle(ColorTokens.Text.tertiary)
                        TextField("", value: $port, format: .number.grouping(.never), prompt: Text(verbatim: "\(selectedDatabaseType.defaultPort)"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .frame(width: SpacingTokens.xxl)
                            .focused($focusedField, equals: .port)
                    }
                }
                validationRow(for: .host)
                validationRow(for: .port)
                additionalServerRows
                PropertyRow(title: "Database") {
                    TextField("", text: $database, prompt: Text("Default"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }
        } header: {
            Text(formTitle)
        }
    }

    private var optionsSection: some View {
        Section {
            DisclosureGroup(isExpanded: $optionsExpanded) {
                if selectedDatabaseType != .sqlite {
                    securityRows
                }
                advancedRows
            } label: {
                LabeledContent("Security and timeouts") {
                    Text(optionsSummary).foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        }
    }

    /// The disclosure's one-line summary of the current values.
    private var optionsSummary: String {
        let timeout = "\(Int(connectionTimeout)) s"
        switch selectedDatabaseType {
        case .microsoftSQL: return "\(mssqlEncryptionMode.shortName) · \(timeout)"
        case .postgresql: return postgresSummary(timeout: timeout)
        case .mysql: return "\(useTLS ? "TLS" : "No TLS") · \(timeout)"
        case .sqlite: return timeout
        }
    }

    @ViewBuilder
    private var savedAsSection: some View {
        Section {
            if isQuickConnect {
                Toggle("Save to Connections", isOn: $saveToConnections.animation())
            }
            if saveToConnections {
                PropertyRow(title: "Name") {
                    TextField("", text: $connectionName, prompt: Text(host.isEmpty ? "My Connection" : host))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .name)
                }
                PropertyRow(title: "Folder") {
                    Picker("", selection: $folderID) {
                        Text("None").tag(nil as UUID?)
                        ForEach(sortedFolders, id: \.id) { folder in
                            Text(folderDisplayName(folder)).tag(folder.id as UUID?)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
                .onChange(of: folderID) { _, newFolderID in
                    if newFolderID == nil && credentialSource == .inherit {
                        credentialSource = .manual
                    }
                }
                ServerAppearanceControls(name: appearanceName, colorHex: $colorHex, glyph: $railGlyph)
            }
        } header: {
            if !isQuickConnect { Text("Saved As") }
        }
    }

    /// The name the appearance preview takes its letters from: the name, else the server.
    private var appearanceName: String {
        let trimmed = connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? host : trimmed
    }

    /// An inline message under a field that stops the form from saving (never a disabled button).
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
    /// Names short enough for the segmented engine picker.
    var shortDisplayName: String {
        self == .microsoftSQL ? "SQL Server" : displayName
    }
}

extension MSSQLEncryptionMode {
    var shortName: String { description.components(separatedBy: " - ").first ?? description }
}

extension TLSMode {
    var shortName: String { description.components(separatedBy: " - ").first ?? description }
}
