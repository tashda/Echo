import SwiftUI

struct ExtendedEventsCreateSheet: View {
    @Bindable var viewModel: ExtendedEventsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.lg) {
            Text("Create Extended Events Session")
                .font(TypographyTokens.prominent.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.primary)

            formFields
            Divider()
            actionButtons
        }
        .padding(SpacingTokens.lg)
        .frame(width: 460)
    }

    private var formFields: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            fieldRow(label: "Session Name") {
                TextField("e.g. SlowQueries", text: $viewModel.createSessionName)
                    .textFieldStyle(.roundedBorder)
            }

            fieldRow(label: "Event") {
                Picker("Event", selection: $viewModel.createEventName) {
                    Text("sql_statement_completed").tag("sqlserver.sql_statement_completed")
                    Text("rpc_completed").tag("sqlserver.rpc_completed")
                    Text("sql_batch_completed").tag("sqlserver.sql_batch_completed")
                    Text("error_reported").tag("sqlserver.error_reported")
                    Text("wait_completed").tag("sqlos.wait_completed")
                    Text("lock_deadlock").tag("sqlserver.lock_deadlock")
                }
                .labelsHidden()
            }

            fieldRow(label: "Filter (WHERE)") {
                TextField("e.g. duration > 1000000", text: $viewModel.createPredicate)
                    .textFieldStyle(.roundedBorder)
            }

            fieldRow(label: "Ring Buffer (KB)") {
                TextField("4096", value: $viewModel.createMaxMemoryKB, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
            }
        }
    }

    private func fieldRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)
                .frame(width: 120, alignment: .trailing)

            content()
        }
    }

    private var actionButtons: some View {
        HStack {
            Spacer()
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button("Create") {
                Task { await viewModel.createSession() }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(viewModel.createSessionName.isEmpty || viewModel.isCreating)
        }
    }
}
