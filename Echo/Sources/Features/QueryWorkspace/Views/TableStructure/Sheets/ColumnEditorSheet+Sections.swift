import SwiftUI

extension ColumnEditorSheet {

    var identitySection: some View {
        Section {
            PropertyRow(title: "Identity Column") {
                Toggle("", isOn: $draft.isIdentity)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            if draft.isIdentity {
                PropertyRow(title: "Seed") {
                    TextField("", text: $draft.identitySeed, prompt: Text("1"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }

                PropertyRow(title: "Increment") {
                    TextField("", text: $draft.identityIncrement, prompt: Text("1"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }

                if databaseType == .postgresql {
                    PropertyRow(title: "Generation") {
                        Picker("", selection: $draft.identityGeneration) {
                            Text("Always").tag("ALWAYS")
                            Text("By Default").tag("BY DEFAULT")
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }
                }
            }
        } header: {
            Text("Identity")
        } footer: {
            if draft.isEditingExisting && draft.isIdentity {
                Text("Identity changes on existing columns require table recreation.")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Status.warning)
            }
        }
    }

    var collationSection: some View {
        Section("Collation") {
            PropertyRow(title: "Collation") {
                TextField("", text: $draft.collation, prompt: Text(databaseType == .postgresql ? "e.g. en_US.utf8" : "e.g. Latin1_General_CI_AS"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}
