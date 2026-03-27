import SwiftUI
import PostgresKit

/// Sheet for creating a new PostgreSQL sequence with all options.
struct NewSequenceSheet: View {
    let session: ConnectionSession
    let schemaName: String
    let onComplete: () -> Void

    @State private var name = ""
    @State private var startWith = "1"
    @State private var incrementBy = "1"
    @State private var minValue = ""
    @State private var maxValue = ""
    @State private var cache = "1"
    @State private var cycle = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    var body: some View {
        SheetLayout(
            title: "New Sequence",
            icon: "number",
            subtitle: "Create a sequence object for generating numbers.",
            primaryAction: "Create",
            canSubmit: isFormValid,
            isSubmitting: isSubmitting,
            errorMessage: errorMessage,
            onSubmit: { await submit() },
            onCancel: { onComplete() }
        ) {
            Form {
                Section("Sequence") {
                    PropertyRow(title: "Name") {
                        TextField("", text: $name, prompt: Text("e.g. order_id_seq"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Schema") {
                        Text(schemaName)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }

                Section("Values") {
                    PropertyRow(title: "Start With") {
                        TextField("", text: $startWith, prompt: Text("1"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Increment By") {
                        TextField("", text: $incrementBy, prompt: Text("1"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Min Value") {
                        TextField("", text: $minValue, prompt: Text("e.g. 1 (optional)"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Max Value") {
                        TextField("", text: $maxValue, prompt: Text("e.g. 9999999 (optional)"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Cache") {
                        TextField("", text: $cache, prompt: Text("1"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Options") {
                    PropertyRow(title: "Cycle") {
                        Toggle("", isOn: $cycle)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 420, idealWidth: 460, minHeight: 380)
    }

    private func submit() async {
        let seqName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !seqName.isEmpty else { return }
        guard let pg = session.session as? PostgresSession else { return }

        isSubmitting = true
        errorMessage = nil

        let handle = AppDirector.shared.activityEngine.begin("Creating sequence \(seqName)", connectionSessionID: session.id)
        do {
            let qualifiedName = "\(ScriptingActions.pgQuote(schemaName)).\(ScriptingActions.pgQuote(seqName))"
            try await pg.client.admin.createSequence(
                name: qualifiedName,
                startWith: Int(startWith),
                incrementBy: Int(incrementBy),
                minValue: minValue.isEmpty ? nil : Int(minValue),
                maxValue: maxValue.isEmpty ? nil : Int(maxValue),
                cache: Int(cache),
                cycle: cycle
            )
            handle.succeed()
            onComplete()
        } catch {
            handle.fail(error.localizedDescription)
            isSubmitting = false
            errorMessage = error.localizedDescription
        }
    }
}
