import SwiftUI
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

extension ConnectionEditorView {
    var detailView: some View {
        VStack(spacing: SpacingTokens.none) {
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
            PropertyRow(title: "Database Type") {
                Picker("", selection: $selectedDatabaseType) {
                    ForEach(DatabaseType.allCases, id: \.self) { type in
                        Label {
                            Text(type.displayName)
                        } icon: {
                            Image(type.iconName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: SpacingTokens.md, height: SpacingTokens.md)
                        }
                        .tag(type)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            PropertyRow(title: "Name") {
                TextField("", text: $connectionName, prompt: Text("My Connection"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            PropertyRow(title: "Color") {
                HStack(spacing: SpacingTokens.xs) {
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
            }
        } header: {
            if isQuickConnect {
                Text("Quick Connect")
            } else {
                Text(originalConnection == nil ? "New Connection" : "Edit Connection")
            }
        }
    }

    private func colorSwatch(color: Color, isSelected: Bool) -> some View {
        Circle().fill(color).frame(width: 20, height: 20)
            .overlay {
                if isSelected {
                    Circle()
                        .strokeBorder(ColorTokens.accent, lineWidth: 2)
                        .padding(-3)
                }
            }
            .overlay(Circle().strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5))
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
            PropertyRow(title: selectedDatabaseType == .sqlite ? "Database File" : "Host") {
                HStack(spacing: SpacingTokens.xs) {
                    TextField(
                        "",
                        text: $host,
                        prompt: Text(selectedDatabaseType == .sqlite ? "/path/to/database.sqlite" : "localhost")
                    )
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)

#if os(macOS)
                    if selectedDatabaseType == .sqlite {
                        Button("Browse") {
                            browseForSQLiteFile()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
#endif
                }
            }

            if selectedDatabaseType != .sqlite {
                PropertyRow(title: "Port") {
                    TextField("", value: $port, format: .number.grouping(.never), prompt: Text(verbatim: "\(selectedDatabaseType.defaultPort)"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }
        } header: {
            Text(selectedDatabaseType == .sqlite ? "Database" : "Server")
        }
    }

    private var organizationSection: some View {
        Section("Organization") {
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
        }
    }
}
