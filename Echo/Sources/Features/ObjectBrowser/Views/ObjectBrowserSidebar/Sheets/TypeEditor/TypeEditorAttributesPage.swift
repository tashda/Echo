import SwiftUI

struct TypeEditorAttributesPage: View {
    @Bindable var viewModel: TypeEditorViewModel

    var body: some View {
        switch viewModel.typeCategory {
        case .composite: compositeSection
        case .enum: enumSection
        case .range: rangeSection
        case .domain: domainSection
        }
    }

    // MARK: - Composite Attributes

    @ViewBuilder
    private var compositeSection: some View {
        Section("Attributes") {
            ForEach($viewModel.attributes) { $attr in
                HStack(spacing: SpacingTokens.sm) {
                    TextField("", text: $attr.name, prompt: Text("name"))
                        .textFieldStyle(.plain)
                        .frame(maxWidth: .infinity)
                    PostgresDataTypePicker(selection: $attr.dataType, prompt: "data type")
                        .frame(maxWidth: .infinity)
                    Button { removeAttribute(attr.id) } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(ColorTokens.Status.error)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.attributes.count <= 1)
                }
            }
            Button { viewModel.attributes.append(TypeAttributeDraft()) } label: {
                Label("Add Attribute", systemImage: "plus.circle")
            }
            .buttonStyle(.plain)
        }
    }

    private func removeAttribute(_ id: UUID) {
        viewModel.attributes.removeAll { $0.id == id }
    }

    // MARK: - Enum Values

    @ViewBuilder
    private var enumSection: some View {
        Section("Values") {
            ForEach($viewModel.enumValues) { $val in
                HStack(spacing: SpacingTokens.sm) {
                    TextField("", text: $val.value, prompt: Text("e.g. active"))
                        .textFieldStyle(.plain)
                        .frame(maxWidth: .infinity)
                    Button { removeEnumValue(val.id) } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(ColorTokens.Status.error)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.enumValues.count <= 1)
                }
            }
            Button { viewModel.enumValues.append(EnumValueDraft()) } label: {
                Label("Add Value", systemImage: "plus.circle")
            }
            .buttonStyle(.plain)
        }

        if viewModel.isEditing {
            Section {
                Text("Existing enum values cannot be removed or reordered. New values are appended at the end.")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
        }
    }

    private func removeEnumValue(_ id: UUID) {
        viewModel.enumValues.removeAll { $0.id == id }
    }

    // MARK: - Range Options

    @ViewBuilder
    private var rangeSection: some View {
        Section("Range Configuration") {
            PropertyRow(title: "Subtype") {
                TextField("", text: $viewModel.subtype, prompt: Text("e.g. integer"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
            PropertyRow(
                title: "Subtype Op Class",
                info: "The operator class used for ordering the subtype values."
            ) {
                TextField("", text: $viewModel.subtypeOpClass, prompt: Text("optional"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
            PropertyRow(title: "Collation") {
                TextField("", text: $viewModel.collation, prompt: Text("optional"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        }

        if viewModel.isEditing {
            Section {
                Text("Range types cannot be altered after creation. To change the subtype, drop and recreate the type.")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
        }
    }

    // MARK: - Domain Options

    @ViewBuilder
    private var domainSection: some View {
        Section("Domain Configuration") {
            PropertyRow(title: "Base Data Type") {
                TextField("", text: $viewModel.baseDataType, prompt: Text("e.g. text"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
            .disabled(viewModel.isEditing)

            PropertyRow(title: "Default Value") {
                TextField("", text: $viewModel.defaultValue, prompt: Text("optional"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            PropertyRow(title: "NOT NULL") {
                Toggle("", isOn: $viewModel.isNotNull)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }

        Section("Constraints") {
            ForEach($viewModel.domainConstraints) { $constraint in
                HStack(spacing: SpacingTokens.sm) {
                    TextField("", text: $constraint.name, prompt: Text("constraint name"))
                        .textFieldStyle(.plain)
                        .frame(maxWidth: 160)
                    TextField("", text: $constraint.expression, prompt: Text("check expression"))
                        .textFieldStyle(.plain)
                        .frame(maxWidth: .infinity)
                    Button { removeConstraint(constraint.id) } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(ColorTokens.Status.error)
                    }
                    .buttonStyle(.plain)
                }
            }
            Button { viewModel.domainConstraints.append(DomainConstraintDraft()) } label: {
                Label("Add Constraint", systemImage: "plus.circle")
            }
            .buttonStyle(.plain)
        }
    }

    private func removeConstraint(_ id: UUID) {
        viewModel.domainConstraints.removeAll { $0.id == id }
    }
}
