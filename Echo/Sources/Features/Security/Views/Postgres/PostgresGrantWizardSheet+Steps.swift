import SwiftUI
import PostgresKit

extension PostgresGrantWizardSheet {

    // MARK: - Step 1: Select Objects

    var objectsStep: some View {
        Form {
            Section("Filter") {
                PropertyRow(title: "Schema") {
                    Picker("", selection: $viewModel.selectedSchema) {
                        ForEach(viewModel.availableSchemas, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                PropertyRow(title: "Object Type") {
                    Picker("", selection: $viewModel.objectType) {
                        ForEach(PostgresGrantWizardViewModel.ObjectType.allCases) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }

            Section {
                if viewModel.isLoadingObjects {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(SpacingTokens.md)
                } else if viewModel.availableObjects.isEmpty {
                    Text("No objects found in this schema.")
                        .font(TypographyTokens.standard)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(SpacingTokens.md)
                } else {
                    objectSelectionList
                }
            } header: {
                HStack {
                    Text("Objects")
                    Spacer()
                    selectAllButtons
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onChange(of: viewModel.selectedSchema) { _, _ in
            Task { await viewModel.loadObjects(session: session) }
        }
        .onChange(of: viewModel.objectType) { _, _ in
            viewModel.selectedPrivileges = []
            Task { await viewModel.loadObjects(session: session) }
        }
    }

    private var objectSelectionList: some View {
        ForEach(viewModel.availableObjects, id: \.self) { objectName in
            objectToggleRow(objectName)
        }
    }

    private func objectToggleRow(_ name: String) -> some View {
        let isSelected = viewModel.selectedObjects.contains(name)
        return Toggle(isOn: Binding(
            get: { isSelected },
            set: { newValue in
                if newValue { viewModel.selectedObjects.insert(name) }
                else { viewModel.selectedObjects.remove(name) }
            }
        )) {
            Text(name)
                .font(TypographyTokens.standard)
        }
        .toggleStyle(.checkbox)
    }

    private var selectAllButtons: some View {
        HStack(spacing: SpacingTokens.sm) {
            Button("Select All") {
                viewModel.selectedObjects = Set(viewModel.availableObjects)
            }
            .buttonStyle(.borderless)
            .font(TypographyTokens.caption)
            .disabled(viewModel.availableObjects.isEmpty)

            Button("Deselect All") {
                viewModel.selectedObjects = []
            }
            .buttonStyle(.borderless)
            .font(TypographyTokens.caption)
            .disabled(viewModel.selectedObjects.isEmpty)
        }
    }

    // MARK: - Step 2: Privileges & Grantee

    var privilegesStep: some View {
        Form {
            Section("Privileges") {
                ForEach(viewModel.objectType.availablePrivileges, id: \.rawValue) { privilege in
                    privilegeToggleRow(privilege)
                }
            }

            Section("Grantee") {
                PropertyRow(title: "Role Name") {
                    TextField("", text: $viewModel.grantee, prompt: Text("e.g. app_readonly"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
                PropertyRow(title: "WITH GRANT OPTION", subtitle: "Allow grantee to grant these privileges to others") {
                    Toggle("", isOn: $viewModel.withGrantOption)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private func privilegeToggleRow(_ privilege: PostgresPrivilege) -> some View {
        let isSelected = viewModel.selectedPrivileges.contains(privilege)
        return Toggle(isOn: Binding(
            get: { isSelected },
            set: { newValue in
                if newValue {
                    if privilege == .all {
                        viewModel.selectedPrivileges = [.all]
                    } else {
                        viewModel.selectedPrivileges.remove(.all)
                        viewModel.selectedPrivileges.insert(privilege)
                    }
                } else {
                    viewModel.selectedPrivileges.remove(privilege)
                }
            }
        )) {
            Text(privilege.rawValue)
                .font(TypographyTokens.standard)
        }
        .toggleStyle(.checkbox)
    }

    // MARK: - Step 3: Review & Apply

    var reviewStep: some View {
        VStack(spacing: 0) {
            summaryHeader
            SQLPreviewSection(sql: viewModel.generatedSQL)
        }
    }

    private var summaryHeader: some View {
        HStack(spacing: SpacingTokens.md) {
            Label("\(viewModel.selectedObjects.count) object(s)", systemImage: "square.stack.3d.up")
            Label(viewModel.selectedPrivileges.map(\.rawValue).sorted().joined(separator: ", "), systemImage: "key")
            Label(viewModel.grantee, systemImage: "person")
            Spacer()
        }
        .font(TypographyTokens.caption)
        .foregroundStyle(ColorTokens.Text.secondary)
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
    }
}
