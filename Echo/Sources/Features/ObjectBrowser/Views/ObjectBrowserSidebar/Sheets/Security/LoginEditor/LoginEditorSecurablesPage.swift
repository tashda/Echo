import SwiftUI

struct LoginEditorSecurablesPage: View {
    @Bindable var viewModel: LoginEditorViewModel

    var body: some View {
        if viewModel.isLoadingSecurables {
            Section {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Loading server permissions\u{2026}")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        } else if !viewModel.isEditing {
            Section {
                Text("Server permissions can be configured after the login is created.")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        } else if viewModel.serverPermissions.isEmpty {
            Section("Server Permissions") {
                Text("No explicit server permissions granted to this login.")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        } else {
            Section("Server Permissions") {
                ForEach($viewModel.serverPermissions) { $perm in
                    HStack {
                        Text(perm.permission)
                            .font(TypographyTokens.formLabel)
                            .frame(minWidth: 160, alignment: .leading)

                        Spacer()

                        Toggle("Grant", isOn: $perm.isGranted)
                            .toggleStyle(.checkbox)
                            .onChange(of: perm.isGranted) { _, granted in
                                if granted { perm.isDenied = false }
                            }

                        Toggle("With Grant", isOn: $perm.withGrantOption)
                            .toggleStyle(.checkbox)
                            .disabled(!perm.isGranted)
                            .onChange(of: perm.withGrantOption) { _, withGrant in
                                if withGrant { perm.isGranted = true; perm.isDenied = false }
                            }

                        Toggle("Deny", isOn: $perm.isDenied)
                            .toggleStyle(.checkbox)
                            .onChange(of: perm.isDenied) { _, denied in
                                if denied { perm.isGranted = false; perm.withGrantOption = false }
                            }
                    }
                }
            }
        }
    }
}
