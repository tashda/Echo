import SwiftUI
import SQLServerKit

struct ProfilerEventPickerSheet: View {
    @Binding var selectedEvents: Set<SQLTraceEvent>
    let onDismiss: () -> Void

    private let templates: [(name: String, events: Set<SQLTraceEvent>)] = [
        ("Standard", [.sqlBatchCompleted, .rpcCompleted]),
        ("TSQL", [.sqlBatchCompleted, .sqlBatchStarting, .sqlStatementCompleted, .sqlStatementStarting]),
        ("Performance", [.sqlBatchCompleted, .rpcCompleted, .degreeOfParallelism, .lockTimeout, .lockDeadlock]),
        ("Connections", [.login, .logout, .existingConnection, .attention]),
        ("Locks", [.lockAcquired, .lockReleased, .lockDeadlock, .lockTimeout, .lockCancel]),
        ("All Events", Set(SQLTraceEvent.allCases))
    ]

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Templates") {
                    ForEach(templates, id: \.name) { template in
                        Button {
                            selectedEvents = template.events
                        } label: {
                            HStack {
                                Text(template.name)
                                    .foregroundStyle(ColorTokens.Text.primary)
                                Spacer()
                                Text("\(template.events.count) events")
                                    .font(TypographyTokens.detail)
                                    .foregroundStyle(ColorTokens.Text.tertiary)
                                if selectedEvents == template.events {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(ColorTokens.accent)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("Individual Events") {
                    ForEach(SQLTraceEvent.allCases, id: \.rawValue) { event in
                        Toggle(isOn: Binding(
                            get: { selectedEvents.contains(event) },
                            set: { isOn in
                                if isOn { selectedEvents.insert(event) }
                                else { selectedEvents.remove(event) }
                            }
                        )) {
                            VStack(alignment: .leading) {
                                Text(event.xeEventName)
                                    .font(TypographyTokens.standard)
                            }
                        }
                        .toggleStyle(.switch)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            HStack(spacing: SpacingTokens.sm) {
                Text("\(selectedEvents.count) events selected")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)

                Spacer()

                Button("Done") { onDismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, SpacingTokens.md2)
            .padding(.vertical, SpacingTokens.sm2)
            .background(.bar)
        }
        .frame(minWidth: 380, idealWidth: 420, minHeight: 420, idealHeight: 500)
        .navigationTitle("Trace Events")
    }
}
