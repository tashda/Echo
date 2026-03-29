import SwiftUI
import SQLServerKit

/// Step 3 of the Generate Scripts wizard: output destination selection.
struct GenerateScriptsOutputStep: View {
    @Bindable var viewModel: GenerateScriptsWizardViewModel

    var body: some View {
        Form {
            Section("Output Destination") {
                Picker("", selection: $viewModel.outputDestination) {
                    ForEach(GenerateScriptsWizardViewModel.OutputDestination.allCases) { dest in
                        Label(dest.rawValue, systemImage: iconForDestination(dest))
                            .tag(dest)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }

            Section {
                selectedObjectsSummary
            } header: {
                Text("Summary")
            } footer: {
                Text("Click Generate to create the script.")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Summary

    private var selectedObjectsSummary: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            PropertyRow(title: "Objects selected") {
                Text("\(viewModel.selectedObjectIDs.count)")
                    .font(TypographyTokens.standard)
                    .foregroundStyle(.secondary)
            }

            PropertyRow(title: "Script mode") {
                Text(viewModel.scriptMode.rawValue)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(.secondary)
            }

            PropertyRow(title: "Drop and Create") {
                Text(viewModel.scriptDropAndCreate ? "Yes" : "No")
                    .font(TypographyTokens.standard)
                    .foregroundStyle(.secondary)
            }

            PropertyRow(title: "Check existence") {
                Text(viewModel.checkExistence ? "Yes" : "No")
                    .font(TypographyTokens.standard)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Icons

    private func iconForDestination(_ dest: GenerateScriptsWizardViewModel.OutputDestination) -> String {
        switch dest {
        case .clipboard: return "doc.on.clipboard"
        case .newQueryWindow: return "doc.text"
        case .file: return "square.and.arrow.down"
        }
    }
}
