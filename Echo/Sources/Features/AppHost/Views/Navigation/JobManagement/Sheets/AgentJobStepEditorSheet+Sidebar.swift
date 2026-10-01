import SwiftUI

/// The settings sidebar at the right (NS4): the step, then what it does when it finishes (OC1).
extension AgentJobStepEditorSheet {
    var sidebar: some View {
        Form {
            Section("Step") {
                nameField
                if isEditing {
                    // The driver can't change a step's type once it exists, so Edit Step shows it.
                    LabeledContent("Type", value: Self.subsystemTitle(subsystem))
                } else {
                    Picker("Type", selection: $subsystem) {
                        ForEach(Self.subsystems, id: \.tag) { Text($0.title).tag($0.tag) }
                    }
                }
                subsystemSpecificFields
            }
            Section("When it finishes") {
                Picker("On success", selection: $outcome.onSuccess) { targetOptions }
                Picker("On failure", selection: $outcome.onFailure) { targetOptions }
                LabeledContent("Retry attempts") {
                    Stepper(value: $outcome.retryAttempts, in: 0...AgentJobStepOutcome.maximumRetryAttempts) {
                        Text("\(outcome.retryAttempts)").monospacedDigit()
                    }
                }
                LabeledContent("Retry interval") {
                    Stepper(value: $outcome.retryIntervalMinutes, in: 0...AgentJobStepOutcome.maximumRetryIntervalMinutes) {
                        Text(outcome.retryIntervalMinutes == 1 ? "1 minute" : "\(outcome.retryIntervalMinutes) minutes").monospacedDigit()
                    }
                }
                .disabled(outcome.retryAttempts == 0)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .controlSize(.small)
        .frame(width: LayoutTokens.AgentJobs.stepSidebarWidth)
        .background(ColorTokens.Workspace.canvas)
    }

    @ViewBuilder
    private var nameField: some View {
        if isEditing {
            // Agent steps can't be renamed through the driver yet; Edit Step shows the name.
            LabeledContent("Name", value: name)
        } else {
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                TextField("Name", text: $name, prompt: Text("e.g. Run cleanup query"))
                    .onChange(of: name) { _, _ in
                        nameHasError = false
                        errorMessage = nil
                    }
                if nameHasError, let errorMessage {
                    Text(errorMessage)
                        .font(TypographyTokens.caption2)
                        .foregroundStyle(ColorTokens.Status.error)
                }
            }
        }
    }

    @ViewBuilder
    private var targetOptions: some View {
        ForEach(AgentJobStepOutcome.targets(otherSteps: Array(otherSteps.keys)), id: \.self) { target in
            Text(target.title(stepNames: otherSteps)).tag(target)
        }
    }

    @ViewBuilder
    var subsystemSpecificFields: some View {
        switch subsystem {
        case "TSQL", "Snapshot", "LogReader", "Distribution", "Merge", "QueueReader":
            Picker("Database", selection: $database) {
                Text("Default").tag("")
                ForEach(databaseNames, id: \.self) { Text($0).tag($0) }
            }
        case "SSIS", "ANALYSISCOMMAND", "ANALYSISQUERY", "CmdExec", "PowerShell", "ActiveScripting":
            if !proxyNames.isEmpty {
                Picker("Run as", selection: $proxyName) {
                    Text("SQL Agent Service Account").tag("")
                    ForEach(proxyNames, id: \.self) { Text($0).tag($0) }
                }
            }
            if ["CmdExec", "PowerShell", "ActiveScripting"].contains(subsystem) {
                TextField("Output file", text: $outputFile, prompt: Text("e.g. C:\\Logs\\step_output.txt"))
            }
        default:
            EmptyView()
        }
    }

    static let subsystems: [(tag: String, title: String)] = [
        ("TSQL", "T-SQL"), ("CmdExec", "CmdExec"), ("PowerShell", "PowerShell"), ("SSIS", "SSIS Package"),
        ("Snapshot", "Snapshot Agent"), ("LogReader", "Log Reader Agent"), ("Distribution", "Distribution Agent"),
        ("Merge", "Merge Agent"), ("QueueReader", "Queue Reader Agent"), ("ANALYSISCOMMAND", "Analysis Services Command"),
        ("ANALYSISQUERY", "Analysis Services Query"), ("ActiveScripting", "ActiveScripting"),
    ]

    static func subsystemTitle(_ tag: String) -> String {
        subsystems.first { $0.tag.caseInsensitiveCompare(tag) == .orderedSame }?.title ?? tag
    }
}
