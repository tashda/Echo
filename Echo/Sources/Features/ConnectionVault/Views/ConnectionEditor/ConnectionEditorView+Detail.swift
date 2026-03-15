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
            Picker("Database Type", selection: $selectedDatabaseType) {
                ForEach(DatabaseType.allCases, id: \.self) { type in
                    Label {
                        Text(type.displayName)
                    } icon: {
                        Image(type.iconName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: SpacingTokens.md, height: SpacingTokens.md)                    }
                    .tag(type)
                }
            }

            TextField("Name", text: $connectionName, prompt: Text("My Connection"))

            LabeledContent("Color") {
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
                .frame(maxWidth: .infinity, alignment: .trailing)
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
        Circle().fill(color).frame(width: SpacingTokens.md2, height: SpacingTokens.md2)
            .overlay {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(TypographyTokens.compact.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .overlay(Circle().strokeBorder(ColorTokens.Text.primary.opacity(0.15), lineWidth: 0.5))
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
                HStack(spacing: SpacingTokens.xs) {
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
}
