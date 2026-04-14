import SwiftUI
import SQLServerKit

struct UserEditorSecurablesPage: View {
    @Bindable var viewModel: UserEditorViewModel
    let session: ConnectionSession

    @State private var showSearchSheet = false

    var body: some View {
        if viewModel.isLoadingSecurables {
            Section {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Loading securables\u{2026}")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        } else {
            securableListSection
            permissionGridSection
        }
    }

    // MARK: - Securable List

    @ViewBuilder
    private var securableListSection: some View {
        Section {
            HStack {
                Button("Add") { showSearchSheet = true }
                    .buttonStyle(.bordered)

                if viewModel.selectedSecurableID != nil {
                    Button("Remove") { removeSelectedSecurable() }
                        .buttonStyle(.bordered)
                }

                Spacer()
            }

            if viewModel.securableEntries.isEmpty {
                Text("No securables added. Click \"Add\" to search for objects.")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
            } else {
                Table(viewModel.securableEntries, selection: $viewModel.selectedSecurableID) {
                    TableColumn("Type") { entry in
                        Text(entry.securable.typeName)
                            .font(TypographyTokens.Table.secondaryName)
                    }
                    .width(min: 80, ideal: 100)

                    TableColumn("Name") { entry in
                        Text(entry.securable.objectName)
                            .font(TypographyTokens.Table.name)
                    }
                    .width(min: 120, ideal: 200)

                    TableColumn("Schema") { entry in
                        Text(entry.securable.schemaName ?? "")
                            .font(TypographyTokens.Table.secondaryName)
                    }
                    .width(min: 60, ideal: 80)
                }
                .tableStyle(.inset(alternatesRowBackgrounds: true))
                .frame(minHeight: 120, maxHeight: 200)
            }
        } header: {
            Text("Securables")
        }
        .sheet(isPresented: $showSearchSheet) {
            UserEditorSecurablesSearchSheet(
                viewModel: viewModel,
                session: session
            ) {
                showSearchSheet = false
            }
        }
    }

    // MARK: - Permission Grid

    @ViewBuilder
    private var permissionGridSection: some View {
        if let selectedID = viewModel.selectedSecurableID,
           let entryIndex = viewModel.securableEntries.firstIndex(where: { $0.id == selectedID }) {
            Section {
                let entry = viewModel.securableEntries[entryIndex]
                if entry.permissions.isEmpty {
                    Text("No permissions defined for this securable.")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                } else {
                    ForEach($viewModel.securableEntries[entryIndex].permissions) { $perm in
                        HStack {
                            Text(perm.permission)
                                .font(TypographyTokens.formLabel)
                                .frame(minWidth: 120, alignment: .leading)

                            Spacer()

                            Toggle("", isOn: $perm.isGranted)
                                .labelsHidden()
                                .toggleStyle(.checkbox)
                                .onChange(of: perm.isGranted) { _, granted in
                                    if granted { perm.isDenied = false }
                                }

                            Toggle("", isOn: $perm.withGrantOption)
                                .labelsHidden()
                                .toggleStyle(.checkbox)
                                .disabled(!perm.isGranted)
                                .onChange(of: perm.withGrantOption) { _, withGrant in
                                    if withGrant { perm.isGranted = true; perm.isDenied = false }
                                }

                            Toggle("", isOn: $perm.isDenied)
                                .labelsHidden()
                                .toggleStyle(.checkbox)
                                .onChange(of: perm.isDenied) { _, denied in
                                    if denied { perm.isGranted = false; perm.withGrantOption = false }
                                }
                        }
                    }
                }
            } header: {
                Text("Permissions for \(viewModel.securableEntries[entryIndex].securable.objectName)")
            }
        }
    }

    // MARK: - Actions

    private func removeSelectedSecurable() {
        guard let selectedID = viewModel.selectedSecurableID else { return }
        viewModel.securableEntries.removeAll { $0.id == selectedID }
        viewModel.selectedSecurableID = nil
    }
}
