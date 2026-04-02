import SwiftUI

struct MySQLProgrammableObjectTemplateSheet: View {
    let kind: MySQLAdvancedObjectsView.DraftKind
    let schema: String
    let connectionID: UUID
    let onDismiss: () -> Void

    @Environment(EnvironmentState.self) private var environmentState

    @State private var name = ""
    @State private var parameters = ""
    @State private var returnType = "TEXT"
    @State private var deterministic = false
    @State private var sqlSecurity = "DEFINER"
    @State private var tableName = ""
    @State private var triggerTiming = "BEFORE"
    @State private var triggerEvent = "INSERT"
    @State private var schedule = "EVERY 1 DAY"
    @State private var preserveCompletion = false
    @State private var eventEnabled = true
    @State private var sqlBody = ""

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            Text(title).font(TypographyTokens.title3)

            Form {
                TextField("", text: $name, prompt: Text("e.g. \(exampleName)"))

                switch kind {
                case .function, .procedure:
                    TextField("", text: $parameters, prompt: Text("e.g. IN p_id INT, IN p_name VARCHAR(100)"))
                    if kind == .function {
                        TextField("", text: $returnType, prompt: Text("e.g. VARCHAR(255)"))
                        Toggle("Deterministic", isOn: $deterministic)
                        Picker("SQL Security", selection: $sqlSecurity) {
                            Text("DEFINER").tag("DEFINER")
                            Text("INVOKER").tag("INVOKER")
                        }
                    }
                case .trigger:
                    TextField("", text: $tableName, prompt: Text("e.g. orders"))
                    Picker("Timing", selection: $triggerTiming) {
                        Text("BEFORE").tag("BEFORE")
                        Text("AFTER").tag("AFTER")
                    }
                    Picker("Event", selection: $triggerEvent) {
                        Text("INSERT").tag("INSERT")
                        Text("UPDATE").tag("UPDATE")
                        Text("DELETE").tag("DELETE")
                    }
                case .event:
                    TextField("", text: $schedule, prompt: Text("e.g. EVERY 1 DAY"))
                    Toggle("Preserve Completion", isOn: $preserveCompletion)
                    Toggle("Enabled", isOn: $eventEnabled)
                }

                TextEditor(text: $sqlBody)
                    .font(TypographyTokens.code)
                    .frame(minHeight: 180)
            }

            HStack {
                Spacer()
                Button("Cancel", action: onDismiss)
                Button("Open Script") {
                    environmentState.openScriptTab(sql: script, connectionID: connectionID)
                    onDismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(SpacingTokens.lg)
        .frame(width: 620)
    }

    private var title: String {
        switch kind {
        case .function: "New MySQL Function"
        case .procedure: "New MySQL Procedure"
        case .trigger: "New MySQL Trigger"
        case .event: "New MySQL Event"
        }
    }

    private var exampleName: String {
        switch kind {
        case .function: "calculate_total"
        case .procedure: "refresh_summary"
        case .trigger: "orders_before_insert"
        case .event: "nightly_cleanup"
        }
    }

    private var script: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        switch kind {
        case .function:
            return MySQLProgrammableObjectScriptBuilder.createScript(
                for: .init(
                    kind: .function,
                    schema: schema,
                    name: trimmedName,
                    parameters: parameters,
                    returnType: returnType,
                    deterministic: deterministic,
                    sqlSecurity: sqlSecurity,
                    body: sqlBody
                )
            )
        case .procedure:
            return MySQLProgrammableObjectScriptBuilder.createScript(
                for: .init(
                    kind: .procedure,
                    schema: schema,
                    name: trimmedName,
                    parameters: parameters,
                    returnType: "",
                    deterministic: false,
                    sqlSecurity: sqlSecurity,
                    body: sqlBody
                )
            )
        case .trigger:
            return MySQLProgrammableObjectScriptBuilder.createScript(
                for: .init(
                    schema: schema,
                    name: trimmedName,
                    tableName: tableName.trimmingCharacters(in: .whitespacesAndNewlines),
                    timing: triggerTiming,
                    event: triggerEvent,
                    body: sqlBody
                )
            )
        case .event:
            return MySQLProgrammableObjectScriptBuilder.createScript(
                for: .init(
                    schema: schema,
                    name: trimmedName,
                    schedule: schedule,
                    preserve: preserveCompletion,
                    enabled: eventEnabled,
                    body: sqlBody
                )
            )
        }
    }
}
