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
        SheetLayout(
            title: "Trace Events",
            icon: "list.bullet.rectangle",
            subtitle: "Select events to capture in the profiler trace.",
            primaryAction: "Done",
            canSubmit: true,
            onSubmit: { onDismiss() },
            onCancel: { onDismiss() }
        ) {
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
        }
        .frame(minWidth: 380, idealWidth: 420, minHeight: 420, idealHeight: 500)
    }
}
