import SwiftUI

extension FolderEditorSheet {

    // MARK: - Form

    var formContent: some View {
        Form {
            Section {
                PropertyRow(title: "Name") {
                    TextField("", text: $name, prompt: Text("Folder name"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }

                if hasDuplicateName {
                    Text("A folder with this name already exists here.")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Status.error)
                        .listRowSeparator(.hidden)
                }

                PropertyRow(title: "Description") {
                    TextField("", text: $folderDescription, prompt: Text("Optional"), axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...3)
                        .multilineTextAlignment(.trailing)
                }

                PropertyRow(title: "Icon") { iconPaletteView }
                PropertyRow(title: "Color") { colorPaletteView }
            } header: {
                Text(isEditing ? "Edit Folder" : "New Folder")
            }

            Section("Location") {
                PropertyRow(title: "Type") {
                    Picker("", selection: $selectedKind) {
                        Text("Connections").tag(FolderKind.connections)
                        Text("Identities").tag(FolderKind.identities)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                PropertyRow(title: "Parent") {
                    Picker("", selection: $selectedParentID) {
                        Text("None").tag(UUID?.none)
                        ForEach(hierarchicalParentFolders, id: \.folder.id) { item in
                            Text(item.path).tag(UUID?.some(item.folder.id))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }

            if !isIdentityFolder {
                credentialsFormSection
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .scrollDisabled(true)
        .onChange(of: credentialMode) { _, newMode in handleCredentialModeChange(newMode) }
        .onChange(of: selectedKind) { _, _ in
            selectedParentID = nil
            selectedIcon = SavedFolder.defaultIcon
            if selectedKind == .identities {
                credentialMode = .none
            }
        }
    }
}
