import SwiftUI
import PostgresKit

struct NewCompositeTypeSheet: View {
    let viewModel: PostgresAdvancedObjectsViewModel
    let onComplete: () -> Void

    @State private var name = ""
    @State private var schema = "public"
    @State private var attributes: [AttributeEntry] = [AttributeEntry()]
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    struct AttributeEntry: Identifiable {
        let id = UUID()
        var name: String = ""
        var dataType: String = ""
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && attributes.contains { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !$0.dataType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        && !isSubmitting
    }

    var body: some View {
        SheetLayout(
            title: "New Composite Type",
            icon: "cube",
            subtitle: "Create a structured type with named attributes.",
            primaryAction: "Create",
            canSubmit: isFormValid,
            isSubmitting: isSubmitting,
            errorMessage: errorMessage,
            onSubmit: { await submit() },
            onCancel: { onComplete() }
        ) {
            Form {
                Section("Type") {
                    PropertyRow(title: "Name") {
                        TextField("", text: $name, prompt: Text("e.g. address"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Schema") {
                        Picker("", selection: $schema) {
                            ForEach(viewModel.availableSchemas, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }

                Section("Attributes") {
                    ForEach($attributes) { $attr in
                        HStack(spacing: SpacingTokens.sm) {
                            TextField("", text: $attr.name, prompt: Text("e.g. street"))
                                .textFieldStyle(.plain)
                                .frame(maxWidth: .infinity)
                            PostgresDataTypePicker(selection: $attr.dataType, prompt: "e.g. text")
                                .frame(maxWidth: .infinity)
                            Button { removeAttribute(attr.id) } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(ColorTokens.Status.error)
                            }
                            .buttonStyle(.plain)
                            .disabled(attributes.count <= 1)
                        }
                    }
                    Button { attributes.append(AttributeEntry()) } label: {
                        Label("Add Attribute", systemImage: "plus.circle")
                    }
                    .buttonStyle(.plain)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 480, idealWidth: 540, minHeight: 400)
    }

    private func removeAttribute(_ id: UUID) {
        attributes.removeAll { $0.id == id }
    }

    private func submit() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let validAttrs = attributes.compactMap { attr -> (name: String, dataType: String)? in
            let n = attr.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let t = attr.dataType.trimmingCharacters(in: .whitespacesAndNewlines)
            return (!n.isEmpty && !t.isEmpty) ? (name: n, dataType: t) : nil
        }
        guard !validAttrs.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        await viewModel.createCompositeType(name: trimmedName, schema: schema, attributes: validAttrs)

        if viewModel.compositeTypes.contains(where: { $0.name == trimmedName }) {
            onComplete()
        } else {
            isSubmitting = false
            errorMessage = "Failed to create composite type"
        }
    }
}
