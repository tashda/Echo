import SwiftUI
import SQLServerKit

struct DACWizardView: View {
    @Bindable var viewModel: DACWizardViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            Divider()
            
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            
            footer
        }
        .frame(width: 550, height: 450)
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(TypographyTokens.title)
                Text(stepDescription)
                    .font(TypographyTokens.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "archivebox")
                .font(TypographyTokens.iconDisplay)
                .foregroundStyle(Color.accentColor)
        }
        .padding(SpacingTokens.lg)
    }
    
    @ViewBuilder
    private var content: some View {
        switch viewModel.currentStep {
        case .selectOperation:
            selectOperationStep
        case .setTarget:
            setTargetStep
        case .progress:
            progressStep
        case .summary:
            summaryStep
        }
    }
    
    private var selectOperationStep: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            Text("Select the operation you want to perform:")
                .padding(.horizontal, SpacingTokens.lg)
            
            List {
                operationRow(mode: .extractDacpac, title: "Extract Data-tier Application", desc: "Extract the schema of a database into a DACPAC file.")
                operationRow(mode: .deployDacpac, title: "Deploy Data-tier Application", desc: "Update a database schema from a DACPAC file.")
                operationRow(mode: .exportBacpac, title: "Export Data-tier Application", desc: "Export schema and data into a BACPAC file.")
                operationRow(mode: .importBacpac, title: "Import Data-tier Application", desc: "Create a new database from a BACPAC file.")
            }
            .listStyle(.bordered)
        }
    }
    
    private func operationRow(mode: DACWizardViewModel.Mode, title: String, desc: String) -> some View {
        Button {
            viewModel.mode = mode
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(TypographyTokens.headline)
                    Text(desc)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if viewModel.mode == mode {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }
    
    private var setTargetStep: some View {
        Form {
            Section("Settings") {
                TextField("Database Name", text: $viewModel.databaseName)
                HStack {
                    TextField("File Path", text: $viewModel.filePath)
                    Button("Browse...") { /* File picker */ }
                }
            }
        }
        .formStyle(.grouped)
    }
    
    private var progressStep: some View {
        VStack(spacing: SpacingTokens.md) {
            ProgressView()
                .controlSize(.large)
            Text(viewModel.statusMessage)
                .font(TypographyTokens.detail)
        }
        .padding(SpacingTokens.xl)
    }
    
    private var summaryStep: some View {
        VStack(spacing: SpacingTokens.md) {
            if let error = viewModel.errorMessage {
                Image(systemName: "xmark.circle.fill")
                    .font(TypographyTokens.iconHero)
                    .foregroundStyle(.red)
                Text("Operation Failed")
                    .font(TypographyTokens.title)
                Text(error)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(TypographyTokens.iconHero)
                    .foregroundStyle(.green)
                Text("Success")
                    .font(TypographyTokens.title)
                Text("The operation completed successfully.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(SpacingTokens.xl)
    }
    
    private var footer: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .buttonStyle(.plain)
            
            Spacer()
            
            if viewModel.currentStep == .setTarget {
                Button("Previous") { viewModel.prevStep() }
            }
            
            if viewModel.currentStep == .selectOperation {
                Button("Next") { viewModel.nextStep() }
                    .buttonStyle(.borderedProminent)
            } else if viewModel.currentStep == .setTarget {
                Button("Run") { viewModel.runOperation() }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.databaseName.isEmpty)
            } else if viewModel.currentStep == .summary {
                Button("Finish") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(SpacingTokens.lg)
    }
    
    private var title: String {
        switch viewModel.mode {
        case .extractDacpac: return "Extract DACPAC"
        case .deployDacpac: return "Deploy DACPAC"
        case .exportBacpac: return "Export BACPAC"
        case .importBacpac: return "Import BACPAC"
        }
    }
    
    private var stepDescription: String {
        switch viewModel.currentStep {
        case .selectOperation: return "Select the desired task"
        case .setTarget: return "Configure target and output"
        case .progress: return "Executing..."
        case .summary: return "Results"
        }
    }
}
