import SwiftUI

struct MySQLUserPasswordSheet: View {
    let accountName: String
    let onApply: (String) -> Void
    let onDismiss: () -> Void

    @State private var password = ""
    @State private var confirmPassword = ""

    var body: some View {
        SheetLayoutCustomFooter(title: "Change Password") {
            Form {
                Section("Account") {
                    LabeledContent("User") {
                        Text(accountName)
                            .textSelection(.enabled)
                    }
                }

                Section("Password") {
                    PropertyRow(title: "New Password") {
                        SecureField("", text: $password, prompt: Text("Enter a new password"))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 240)
                    }

                    PropertyRow(title: "Confirm Password") {
                        SecureField("", text: $confirmPassword, prompt: Text("Re-enter the new password"))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 240)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        } footer: {
            if !passwordsMatch && !confirmPassword.isEmpty {
                Text("Passwords must match.")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Status.error)
            }
            Spacer()
            Button("Cancel") { onDismiss() }
                .keyboardShortcut(.cancelAction)
            Button("Save") {
                onApply(password)
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(password.isEmpty || !passwordsMatch)
        }
        .frame(minWidth: 520, minHeight: 280)
    }

    private var passwordsMatch: Bool {
        password == confirmPassword
    }
}
