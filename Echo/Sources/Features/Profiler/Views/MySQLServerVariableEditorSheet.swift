import SwiftUI

struct MySQLServerVariableEditorSheet: View {
    let variable: ServerPropertiesViewModel.PropertyItem
    let onSave: (String) -> Void
    let onDismiss: () -> Void

    @State private var value: String

    init(
        variable: ServerPropertiesViewModel.PropertyItem,
        onSave: @escaping (String) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.variable = variable
        self.onSave = onSave
        self.onDismiss = onDismiss
        _value = State(initialValue: variable.value)
    }

    var body: some View {
        SheetLayoutCustomFooter(title: "Edit Global Variable") {
            Form {
                Section("Variable") {
                    LabeledContent("Name") {
                        Text(variable.name)
                            .textSelection(.enabled)
                    }
                }

                Section("Value") {
                    TextField("", text: $value, prompt: Text("Enter a valid MySQL literal"))
                        .textFieldStyle(.roundedBorder)
                    Text("Enter the SQL literal to send with `SET GLOBAL`, for example `1`, `'STRICT_ALL_TABLES'`, or `utf8mb4`.")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        } footer: {
            HStack {
                Button("Cancel") { onDismiss() }
                Spacer()
                Button("Save") {
                    onSave(value)
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .frame(minWidth: 520, minHeight: 240)
    }
}
