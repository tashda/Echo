import SwiftUI
import PostgresKit

struct PostgresGrantWizardSheet: View {
    @Bindable var viewModel: PostgresGrantWizardViewModel
    let session: DatabaseSession
    let onComplete: () -> Void

    var body: some View {
        SheetLayoutCustomFooter(title: "Grant Wizard") {
            stepIndicator
            Divider()
            stepContent
        } footer: {
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Status.error)
                    .lineLimit(1)
            }
            Spacer()

            Button("Cancel") { onComplete() }
                .keyboardShortcut(.cancelAction)

            if viewModel.currentStep != .objects {
                Button("Back") { viewModel.goBack() }
            }

            wizardPrimaryButton
        }
        .frame(minWidth: 560, idealWidth: 620, minHeight: 480)
        .task {
            await viewModel.loadSchemas(session: session)
            await viewModel.loadObjects(session: session)
        }
    }

    @ViewBuilder
    private var wizardPrimaryButton: some View {
        switch viewModel.currentStep {
        case .objects:
            primaryActionButton("Next", canSubmit: viewModel.canProceedFromObjects) {
                viewModel.goNext()
            }
        case .privileges:
            primaryActionButton("Next", canSubmit: viewModel.canProceedFromPrivileges) {
                viewModel.goNext()
            }
        case .review:
            primaryActionButton("Apply", canSubmit: viewModel.canApply) {
                await apply()
            }
        }
    }

    @ViewBuilder
    private func primaryActionButton(_ label: String, canSubmit: Bool, action: @escaping () async -> Void) -> some View {
        if canSubmit {
            Button(label) { Task { await action() } }
                .buttonStyle(.bordered)
                .keyboardShortcut(.defaultAction)
        } else {
            Button(label) {}
                .buttonStyle(.bordered)
                .disabled(true)
                .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: SpacingTokens.lg) {
            ForEach(PostgresGrantWizardViewModel.Step.allCases, id: \.rawValue) { step in
                stepBadge(step)
            }
        }
        .padding(.horizontal, SpacingTokens.md2)
        .padding(.vertical, SpacingTokens.sm2)
    }

    private func stepBadge(_ step: PostgresGrantWizardViewModel.Step) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            Circle()
                .fill(step == viewModel.currentStep ? Color.accentColor : ColorTokens.Background.tertiary)
                .frame(width: 24, height: 24)
                .overlay {
                    Text("\(step.rawValue + 1)")
                        .font(TypographyTokens.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(step == viewModel.currentStep ? .white : ColorTokens.Text.secondary)
                }
            Text(step.title)
                .font(TypographyTokens.standard)
                .foregroundStyle(step == viewModel.currentStep ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.currentStep {
        case .objects:
            objectsStep
        case .privileges:
            privilegesStep
        case .review:
            reviewStep
        }
    }

    private func apply() async {
        await viewModel.apply(session: session)
        if viewModel.errorMessage == nil {
            onComplete()
        }
    }
}
