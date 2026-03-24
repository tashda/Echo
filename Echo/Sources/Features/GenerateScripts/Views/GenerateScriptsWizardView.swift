import SwiftUI
import SQLServerKit

struct GenerateScriptsWizardView: View {
    @Bindable var viewModel: GenerateScriptsWizardViewModel
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
        .frame(width: 600, height: 500)
        .onAppear {
            viewModel.loadObjects()
        }
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Generate Scripts")
                    .font(TypographyTokens.title)
                Text(stepDescription)
                    .font(TypographyTokens.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "script.badge.plus")
                .font(.system(size: 32))
                .foregroundStyle(Color.accentColor)
        }
        .padding(SpacingTokens.lg)
    }
    
    @ViewBuilder
    private var content: some View {
        if viewModel.isScripting {
            VStack(spacing: SpacingTokens.md) {
                ProgressView(value: viewModel.progress)
                    .progressViewStyle(.linear)
                Text(viewModel.statusMessage)
                    .font(TypographyTokens.detail)
            }
            .padding(SpacingTokens.xl)
        } else {
            switch viewModel.currentStep {
            case .selectObjects:
                selectObjectsStep
            case .setOptions:
                setOptionsStep
            case .outputDestination:
                outputDestinationStep
            case .summary:
                summaryStep
            }
        }
    }
    
    private var selectObjectsStep: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text("Select the objects you want to script:")
                .padding(.horizontal, SpacingTokens.lg)
            
            if viewModel.isLoadingObjects {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.objects, id: \.self, selection: $viewModel.selectedObjectIDs) { obj in
                    HStack {
                        Image(systemName: iconForType(obj.type))
                            .foregroundStyle(.secondary)
                        Text(obj.qualifiedName)
                        Spacer()
                        Text(obj.type)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(.tertiary)
                    }
                }
                .listStyle(.bordered)
            }
        }
    }
    
    private var setOptionsStep: some View {
        Form {
            Section("General Scripting Options") {
                Toggle("Include Dependencies", isOn: $viewModel.includeDependencies)
                Toggle("Check for existence (IF EXISTS)", isOn: $viewModel.checkForExistence)
                Toggle("Script DROP and CREATE", isOn: $viewModel.scriptDropAndCreate)
            }
            
            Section("Data Options") {
                Toggle("Script Data (INSERT statements)", isOn: $viewModel.scriptData)
            }
        }
        .formStyle(.grouped)
    }
    
    private var outputDestinationStep: some View {
        Form {
            Section("Output Destination") {
                Picker("Destination", selection: $viewModel.destination) {
                    ForEach(GenerateScriptsWizardViewModel.Destination.allCases) { dest in
                        Text(dest.rawValue).tag(dest)
                    }
                }
                .pickerStyle(.radioGroup)
            }
        }
        .formStyle(.grouped)
    }
    
    private var summaryStep: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            Label("Script generation successful", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(TypographyTokens.headline)
            
            ScrollView {
                Text(viewModel.resultScript)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(SpacingTokens.sm)
            }
            .background(Color.black.opacity(0.05))
            .cornerRadius(4)
        }
        .padding(SpacingTokens.lg)
    }
    
    private var footer: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .buttonStyle(.plain)
            
            Spacer()
            
            if viewModel.currentStep.rawValue > 1 && viewModel.currentStep != .summary {
                Button("Previous") { viewModel.prevStep() }
            }
            
            if viewModel.currentStep == .outputDestination {
                Button("Generate") { viewModel.generate() }
                    .buttonStyle(.borderedProminent)
            } else if viewModel.currentStep == .summary {
                Button("Finish") { dismiss() }
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Next") { viewModel.nextStep() }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.selectedObjectIDs.isEmpty)
            }
        }
        .padding(SpacingTokens.lg)
    }
    
    private var stepDescription: String {
        switch viewModel.currentStep {
        case .selectObjects: return "Step 1: Choose database objects"
        case .setOptions: return "Step 2: Configure scripting options"
        case .outputDestination: return "Step 3: Select output method"
        case .summary: return "Generation Summary"
        }
    }
    
    private func iconForType(_ type: String) -> String {
        switch type {
        case "U": return "tablecells"
        case "V": return "view.2d"
        case "P": return "gearshape.fill"
        default: return "cube"
        }
    }
}
