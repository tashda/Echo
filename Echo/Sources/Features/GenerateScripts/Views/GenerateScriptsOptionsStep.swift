import SwiftUI
import SQLServerKit

/// Step 2 of the Generate Scripts wizard: scripting option configuration.
struct GenerateScriptsOptionsStep: View {
    @Bindable var viewModel: GenerateScriptsWizardViewModel

    var body: some View {
        Form {
            Section("Script Mode") {
                PropertyRow(title: "Script mode") {
                    Picker("", selection: $viewModel.scriptMode) {
                        ForEach(SQLServerScriptingOptions.ScriptMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }

            Section("Object Options") {
                PropertyRow(title: "Include permissions") {
                    Toggle("", isOn: $viewModel.includePermissions)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                PropertyRow(title: "Include triggers") {
                    Toggle("", isOn: $viewModel.includeTriggers)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                PropertyRow(title: "Include indexes") {
                    Toggle("", isOn: $viewModel.includeIndexes)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                PropertyRow(title: "Include extended properties") {
                    Toggle("", isOn: $viewModel.includeExtendedProperties)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }

            Section("Script Behavior") {
                PropertyRow(
                    title: "Check existence (IF NOT EXISTS)",
                    info: "Wraps each object creation in an existence check so the script is re-runnable."
                ) {
                    Toggle("", isOn: $viewModel.checkExistence)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                PropertyRow(
                    title: "Script DROP and CREATE",
                    info: "Adds a DROP statement before each CREATE. Overrides the existence check option."
                ) {
                    Toggle("", isOn: $viewModel.scriptDropAndCreate)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                PropertyRow(title: "Include USE database") {
                    Toggle("", isOn: $viewModel.includeUseDatabase)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}
