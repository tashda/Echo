import SwiftUI
import SQLServerKit

/// Shared event editing controls used by both create and edit sheets.
/// Includes the event picker, action toggles, and predicate field.
struct ExtendedEventsEventControls: View {
    @Bindable var viewModel: ExtendedEventsViewModel
    var onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack {
                eventPicker
                Button("Add") { onAdd() }
                    .disabled(viewModel.newEventName.isEmpty)
            }

            if !viewModel.newEventName.isEmpty {
                actionToggles
                predicateField
            }
        }
    }

    private var eventPicker: some View {
        Group {
            if viewModel.availableEvents.isEmpty {
                Picker("Event", selection: $viewModel.newEventName) {
                    Text("Select event\u{2026}").tag("")
                    Section("Common") {
                        Text("sql_statement_completed").tag("sqlserver.sql_statement_completed")
                        Text("rpc_completed").tag("sqlserver.rpc_completed")
                        Text("sql_batch_completed").tag("sqlserver.sql_batch_completed")
                        Text("error_reported").tag("sqlserver.error_reported")
                        Text("wait_completed").tag("sqlos.wait_completed")
                        Text("lock_deadlock").tag("sqlserver.lock_deadlock")
                    }
                }
            } else {
                let grouped = Dictionary(grouping: viewModel.availableEvents, by: \.packageName)
                let packages = grouped.keys.sorted()

                Picker("Event", selection: $viewModel.newEventName) {
                    Text("Select event\u{2026}").tag("")
                    ForEach(packages, id: \.self) { pkg in
                        Section(pkg) {
                            ForEach(grouped[pkg] ?? [], id: \.id) { event in
                                Text(event.eventName).tag(event.id)
                            }
                        }
                    }
                }
            }
        }
    }

    private var actionToggles: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            Text("Actions")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)

            FlowLayout(spacing: SpacingTokens.xxs2) {
                ForEach(Self.commonActions, id: \.self) { action in
                    let shortName = action.replacingOccurrences(of: "sqlserver.", with: "")
                    Toggle(shortName, isOn: Binding(
                        get: { viewModel.newEventActions.contains(action) },
                        set: { if $0 { viewModel.newEventActions.insert(action) } else { viewModel.newEventActions.remove(action) } }
                    ))
                    .toggleStyle(.checkbox)
                    .font(TypographyTokens.detail)
                }
            }
        }
    }

    private var predicateField: some View {
        TextField("WHERE predicate (optional)", text: $viewModel.newEventPredicate, prompt: Text("e.g. duration > 1000000"))
            .font(.system(size: 11, design: .monospaced))
    }

    static let commonActions: [String] = [
        "sqlserver.sql_text",
        "sqlserver.database_name",
        "sqlserver.username",
        "sqlserver.client_hostname",
        "sqlserver.client_app_name",
        "sqlserver.session_id",
        "sqlserver.query_hash",
        "sqlserver.plan_handle"
    ]
}
