import SwiftUI
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

extension ConnectionEditorView {
    var detailView: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                Form {
                    generalSection
                    organizationSection
                    serverSection
                    if selectedDatabaseType != .sqlite {
                        authenticationSection
                        securitySection
                    }
                    testConnectionSection
                        .id("testSection")
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .onChange(of: testLogEntries.count) {
                    withAnimation {
                        proxy.scrollTo("testSection", anchor: .bottom)
                    }
                }
                .onChange(of: isTestingConnection) {
                    if isTestingConnection {
                        withAnimation {
                            proxy.scrollTo("testSection", anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            toolbarView
        }
    }

    private var generalSection: some View {
        Section {
            Picker("Database Type", selection: $selectedDatabaseType) {
                ForEach(DatabaseType.allCases, id: \.self) { type in
                    Label {
                        Text(type.displayName)
                    } icon: {
                        Image(type.iconName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16)
                    }
                    .tag(type)
                }
            }

            TextField("Name", text: $connectionName, prompt: Text("My Connection"))

            LabeledContent("Color") {
                HStack(spacing: 8) {
                    ForEach(Self.colorPalette, id: \.self) { hex in
                        let swatch = Color(hex: hex) ?? .accentColor
                        colorSwatch(color: swatch, isSelected: colorHex.uppercased() == hex.uppercased())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.15)) { colorHex = hex.uppercased() }
                            }
                    }

                    ColorPicker("", selection: colorBinding, supportsOpacity: false)
                        .labelsHidden()
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        } header: {
            Text(originalConnection == nil ? "New Connection" : "Edit Connection")
        }
    }

    private func colorSwatch(color: Color, isSelected: Bool) -> some View {
        Circle().fill(color).frame(width: 20, height: 20)
            .overlay {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .overlay(Circle().strokeBorder(.primary.opacity(0.15), lineWidth: 0.5))
            .contentShape(Circle())
    }

    internal var colorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: colorHex) ?? .accentColor },
            set: { color in colorHex = color.toHex() ?? colorHex }
        )
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
                    TextField("", value: $port, format: .number.grouping(.never), prompt: Text(verbatim: "\(selectedDatabaseType.defaultPort)"))
                        .multilineTextAlignment(.trailing)
                }

            }
        } header: {
            Text(selectedDatabaseType == .sqlite ? "Database" : "Server")
        }
    }

    private var organizationSection: some View {
        Section("Organization") {
            Picker("Folder", selection: $folderID) {
                Text("None").tag(nil as UUID?)
                ForEach(sortedFolders, id: \.id) { folder in
                    Text(folderDisplayName(folder)).tag(folder.id as UUID?)
                }
            }
            .onChange(of: folderID) { _, newFolderID in
                if newFolderID == nil && credentialSource == .inherit {
                    credentialSource = .manual
                }
            }
        }
    }

    private var testConnectionSection: some View {
        Section {
            LabeledContent("Test") {
                Button(action: handleTestButton) {
                    HStack(spacing: 6) {
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
        VStack(alignment: .leading, spacing: 2) {
            ForEach(testLogEntries) { entry in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(entry.timestamp, format: .dateTime.hour().minute().second())
                        .foregroundStyle(.tertiary)
                    Text(entry.message)
                        .foregroundStyle(logEntryColor(entry.kind))
                        .textSelection(.enabled)
                }
                .font(.system(size: 11, design: .monospaced))
            }

            if isTestingConnection {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text("Waiting for response...")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SpacingTokens.xs)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 4))
    }

    private func logEntryColor(_ kind: TestLogEntry.Kind) -> Color {
        switch kind {
        case .info: .secondary
        case .success: .green
        case .error: .red
        }
    }

    var toolbarView: some View {
        HStack {
            Spacer()

            Button("Cancel", role: .cancel) {
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
            .keyboardShortcut(.defaultAction)
            .disabled(!isFormValid)
        }
        .padding(SpacingTokens.md2)
    }
}
