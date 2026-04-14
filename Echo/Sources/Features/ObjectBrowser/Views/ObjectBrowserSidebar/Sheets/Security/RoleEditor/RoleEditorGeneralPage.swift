import SwiftUI

struct RoleEditorGeneralPage: View {
    @Bindable var viewModel: RoleEditorViewModel

    var body: some View {
        Section("Identity") {
            if viewModel.isEditing {
                PropertyRow(title: "Role Name") {
                    Text(viewModel.roleName)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            } else {
                PropertyRow(title: "Role Name") {
                    TextField("", text: $viewModel.roleName, prompt: Text("e.g. data_readers"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }

            PropertyRow(title: "Owner") {
                if viewModel.isEditing {
                    Text(viewModel.owner.isEmpty ? "dbo" : viewModel.owner)
                        .foregroundStyle(ColorTokens.Text.secondary)
                } else if viewModel.availableOwners.isEmpty {
                    TextField("", text: $viewModel.owner, prompt: Text("dbo"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                } else {
                    Picker("", selection: $viewModel.owner) {
                        Text("Default (dbo)").tag("")
                        ForEach(viewModel.availableOwners, id: \.self) { ownerName in
                            Text(ownerName).tag(ownerName)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }
        }

        Section {
            PropertyRow(title: "Database") {
                Text(viewModel.databaseName)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
    }
}
