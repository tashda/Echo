import SwiftUI

/// Represents a pending edit action for advanced object context menus.
struct PendingEdit: Identifiable {
    enum Action {
        case rename
        case changeOwner
        case changeSchema
    }

    let action: Action
    let objectName: String
    let initialValue: String

    var id: String { "\(action)-\(objectName)" }

    var title: String {
        switch action {
        case .rename: "Rename"
        case .changeOwner: "Change Owner"
        case .changeSchema: "Change Schema"
        }
    }

    var fieldLabel: String {
        switch action {
        case .rename: "New Name"
        case .changeOwner: "New Owner"
        case .changeSchema: "New Schema"
        }
    }
}

struct SingleFieldEditSheet: View {
    let title: String
    let fieldLabel: String
    let initialValue: String
    let onSubmit: (String) async -> Void
    let onCancel: () -> Void

    @State private var value: String
    @State private var isSubmitting = false

    init(
        title: String,
        fieldLabel: String,
        initialValue: String,
        onSubmit: @escaping (String) async -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.fieldLabel = fieldLabel
        self.initialValue = initialValue
        self.onSubmit = onSubmit
        self.onCancel = onCancel
        _value = State(initialValue: initialValue)
    }

    private var canSubmit: Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    var body: some View {
        SheetLayout(
            title: title,
            icon: "pencil",
            subtitle: "Edit the value for this object.",
            primaryAction: "Apply",
            canSubmit: canSubmit,
            isSubmitting: isSubmitting,
            onSubmit: {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                isSubmitting = true
                await onSubmit(trimmed)
                onCancel()
            },
            onCancel: { onCancel() }
        ) {
            Form {
                Section(title) {
                    PropertyRow(title: fieldLabel) {
                        TextField("", text: $value, prompt: Text(initialValue))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 360, idealWidth: 400, minHeight: 160)
    }
}
