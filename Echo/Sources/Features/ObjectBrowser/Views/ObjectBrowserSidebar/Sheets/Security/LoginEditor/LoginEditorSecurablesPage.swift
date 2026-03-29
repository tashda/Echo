import SwiftUI

struct LoginEditorSecurablesPage: View {
    @Bindable var viewModel: LoginEditorViewModel

    var body: some View {
        if !viewModel.isEditing {
            Section {
                Text("Server permissions can be configured after the login is created.")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        } else if viewModel.serverPermissions.isEmpty {
            Section {
                Text("No server permissions available.")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        } else {
            permissionTable
        }
    }

    @ViewBuilder
    private var permissionTable: some View {
        Section {
            Grid(alignment: .leading, horizontalSpacing: SpacingTokens.md, verticalSpacing: 0) {
                GridRow {
                    Text("Permission")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Grant")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .frame(width: 50)
                    Text("With Grant")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .frame(width: 70)
                    Text("Deny")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .frame(width: 50)
                }
                .padding(.bottom, SpacingTokens.xs)

                Divider()

                ForEach($viewModel.serverPermissions) { $perm in
                    GridRow {
                        Text(perm.permission)
                            .font(TypographyTokens.formLabel)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(permissionHasChange(perm) ? ColorTokens.Text.primary : ColorTokens.Text.secondary)

                        Toggle("", isOn: $perm.isGranted)
                            .labelsHidden()
                            .toggleStyle(.checkbox)
                            .frame(width: 50)
                            .onChange(of: perm.isGranted) { _, granted in
                                if granted { perm.isDenied = false }
                            }

                        Toggle("", isOn: $perm.withGrantOption)
                            .labelsHidden()
                            .toggleStyle(.checkbox)
                            .frame(width: 70)
                            .disabled(!perm.isGranted)
                            .onChange(of: perm.withGrantOption) { _, withGrant in
                                if withGrant { perm.isGranted = true; perm.isDenied = false }
                            }

                        Toggle("", isOn: $perm.isDenied)
                            .labelsHidden()
                            .toggleStyle(.checkbox)
                            .frame(width: 50)
                            .onChange(of: perm.isDenied) { _, denied in
                                if denied { perm.isGranted = false; perm.withGrantOption = false }
                            }
                    }
                    .padding(.vertical, SpacingTokens.xxxs)
                }
            }
        }
    }

    private func permissionHasChange(_ perm: LoginEditorPermissionEntry) -> Bool {
        perm.isGranted != perm.originalState.isGranted ||
        perm.withGrantOption != perm.originalState.withGrantOption ||
        perm.isDenied != perm.originalState.isDenied
    }
}
