import SwiftUI
import SQLServerKit

/// Multi-step wizard sheet for bulk scripting database objects.
struct GenerateScriptsWizardView: View {
    @Bindable var viewModel: GenerateScriptsWizardViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            footer
        }
        .frame(width: 600, height: 520)
        .navigationTitle("Generate Scripts")
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
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(SpacingTokens.sm)
                    .textSelection(.enabled)
            }
            .background(ColorTokens.Background.secondary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(SpacingTokens.lg)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: SpacingTokens.sm) {
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
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Next") { viewModel.nextStep() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.canGoNext)
                        .keyboardShortcut(.defaultAction)
                }
            }

            if viewModel.generationSucceeded {
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, SpacingTokens.md2)
        .padding(.vertical, SpacingTokens.sm2)
        .background(.bar)
    }
}
