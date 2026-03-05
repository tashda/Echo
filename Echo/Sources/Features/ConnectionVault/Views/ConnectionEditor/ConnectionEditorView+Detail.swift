import SwiftUI
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

extension ConnectionEditorView {
    var detailView: some View {
        VStack(spacing: 0) {
            ScrollView {
                Form {
                    generalSection
                    organizationSection
                    serverSection
                    authenticationSection
                    securitySection
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
            }

            Divider()

            toolbarView
        }
    }

    private var generalSection: some View {
        Section {
            LabeledContent("Name") {
                TextField("", text: $connectionName, prompt: Text("My Connection"))
                    .multilineTextAlignment(.trailing)
            }

            LabeledContent("Color") {
                HStack(spacing: 8) {
                    ForEach(Self.colorPalette, id: \.self) { hex in
                        Button {
                            colorHex = hex.uppercased()
                        } label: {
                            Circle()
                                .fill(Color(hex: hex) ?? .accentColor)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .strokeBorder(
                                            Color.primary.opacity(colorHex.uppercased() == hex.uppercased() ? 0.6 : 0.2),
                                            lineWidth: colorHex.uppercased() == hex.uppercased() ? 2.5 : 1
                                        )
                                )
                                .overlay(
                                    Group {
                                        if colorHex.uppercased() == hex.uppercased() {
                                            Image(systemName: "checkmark")
                                                .font(TypographyTokens.detail.weight(.bold))
                                                .foregroundStyle(.white)
                                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 0.5)
                                        }
                                    }
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } header: {
            Text("General")
        }
    }

    private var organizationSection: some View {
        Section {
            Picker("Folder", selection: $folderID) {
                Text("Root").tag(nil as UUID?)
                ForEach(sortedFolders, id: \.id) { folder in
                    Text(folderDisplayName(folder)).tag(folder.id as UUID?)
                }
            }
            .onChange(of: folderID) { _, newFolderID in
                if newFolderID == nil && credentialSource == .inherit {
                    credentialSource = .manual
                }
            }
        } header: {
            Text("Organization")
        }
    }

    private var serverSection: some View {
        Section {
            LabeledContent(selectedDatabaseType == .sqlite ? "Database File" : "Host") {
                HStack(spacing: 8) {
                    TextField(
                        "",
                        text: $host,
                        prompt: Text(selectedDatabaseType == .sqlite ? "/path/to/database.sqlite" : "localhost")
                    )
                    .multilineTextAlignment(.trailing)

#if os(macOS)
                    if selectedDatabaseType == .sqlite {
                        Button("Browse...") {
                            browseForSQLiteFile()
                        }
                        .buttonStyle(.borderless)
                    }
#endif
                }
            }

            if selectedDatabaseType != .sqlite {
                LabeledContent("Port") {
                    TextField("", value: $port, format: .number.grouping(.never), prompt: Text("\(selectedDatabaseType.defaultPort)"))
                        .multilineTextAlignment(.trailing)
                }

                LabeledContent("Database") {
                    TextField("", text: $database, prompt: Text("postgres (optional)"))
                        .multilineTextAlignment(.trailing)
                }
            } else {
                LabeledContent("Database") {
                    Text("Not required")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        } header: {
            Text(selectedDatabaseType == .sqlite ? "Database" : "Server")
        }
    }

    var toolbarView: some View {
        HStack(spacing: 12) {
            Button(action: handleTestButton) {
                HStack(spacing: 6) {
                    if isTestingConnection {
                        ProgressView().controlSize(.small)
                        Text("Cancel Test")
                    } else {
                        Image(systemName: "link.badge.plus")
                        Text("Test Connection")
                    }
                }
            }
            .buttonStyle(.bordered)
            .disabled(!isTestingConnection && !isFormValid)

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button("Save") {
                handleSave(action: .save)
            }
            .disabled(!isFormValid)

            Button("Save & Connect") {
                handleSave(action: .saveAndConnect)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isFormValid)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, SpacingTokens.md2)
        .padding(.vertical, SpacingTokens.sm2)
        .background(.ultraThinMaterial)
    }
}
