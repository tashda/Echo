import SwiftUI

/// Multi-step wizard sheet for bulk scripting database objects.
struct GenerateScriptsWizardView: View {
    @Bindable var viewModel: GenerateScriptsWizardViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SheetLayoutCustomFooter(title: "Generate Scripts") {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } footer: {
            if viewModel.generationSucceeded && viewModel.outputDestination == .file {
                Button("Save to File") {
                    viewModel.saveToFile()
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)

            if !viewModel.generationSucceeded && !viewModel.isGenerating {
                if viewModel.currentStep.rawValue > 1 {
                    Button("Back") { viewModel.previousStep() }
                }

                if viewModel.currentStep == .output {
                    Button("Generate") { viewModel.generate() }
                        .buttonStyle(.bordered)
                        .keyboardShortcut(.defaultAction)
                } else {
                    if viewModel.canGoNext {
                        Button("Next") { viewModel.nextStep() }
                            .buttonStyle(.bordered)
                            .keyboardShortcut(.defaultAction)
                    } else {
                        Button("Next") {}
                            .buttonStyle(.bordered)
                            .disabled(true)
                            .keyboardShortcut(.defaultAction)
                    }
                }
            }

            if viewModel.generationSucceeded {
                Button("Done") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .frame(width: 600, height: 520)
        .onAppear {
            viewModel.loadObjects()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isGenerating {
            generatingOverlay
        } else if viewModel.generationSucceeded {
            successOverlay
        } else {
            switch viewModel.currentStep {
            case .selectObjects:
                GenerateScriptsSelectObjectsStep(viewModel: viewModel)
            case .setOptions:
                GenerateScriptsOptionsStep(viewModel: viewModel)
            case .output:
                GenerateScriptsOutputStep(viewModel: viewModel)
            }
        }
    }

    // MARK: - Generating Overlay

    private var generatingOverlay: some View {
        VStack(spacing: SpacingTokens.md) {
            ProgressView(value: viewModel.progress)
                .progressViewStyle(.linear)
            Text(viewModel.statusMessage)
                .font(TypographyTokens.detail)
                .foregroundStyle(.secondary)
        }
        .padding(SpacingTokens.xl)
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        VStack(spacing: SpacingTokens.md) {
            Label("Script generated successfully", systemImage: "checkmark.circle.fill")
                .foregroundStyle(ColorTokens.Status.success)
                .font(TypographyTokens.headline)

            if let error = viewModel.generationError {
                Text(error)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Status.error)
            }

            ScrollView {
                Text(viewModel.generatedScript.prefix(5000))
                    .font(TypographyTokens.code)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(SpacingTokens.sm)
                    .textSelection(.enabled)
            }
            .background(ColorTokens.Background.secondary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(SpacingTokens.lg)
    }
}
