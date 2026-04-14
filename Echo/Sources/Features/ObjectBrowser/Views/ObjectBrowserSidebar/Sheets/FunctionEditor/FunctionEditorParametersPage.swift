import SwiftUI

struct FunctionEditorParametersPage: View {
    @Bindable var viewModel: FunctionEditorViewModel

    var body: some View {
        Section {
            if viewModel.parameters.isEmpty {
                emptyState
            } else {
                parameterTable
            }
        } header: {
            HStack {
                Text("Parameters")
                Spacer()
                Button {
                    viewModel.parameters.append(FunctionParameterDraft())
                } label: {
                    Label("Add Parameter", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Text("No parameters defined. Click + to add one.")
            .font(TypographyTokens.formDescription)
            .foregroundStyle(ColorTokens.Text.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, SpacingTokens.lg)
    }

    // MARK: - Parameter Table

    private var parameterTable: some View {
        ForEach($viewModel.parameters) { $param in
            parameterRow(param: $param)
                .contextMenu {
                    Button("Delete", role: .destructive) {
                        viewModel.parameters.removeAll { $0.id == param.id }
                    }
                }
        }
        .onMove { source, destination in
            viewModel.parameters.move(fromOffsets: source, toOffset: destination)
        }
    }

    // MARK: - Parameter Row

    private func parameterRow(param: Binding<FunctionParameterDraft>) -> some View {
        HStack(spacing: SpacingTokens.sm) {
            TextField("", text: param.name, prompt: Text("name"))
                .textFieldStyle(.plain)
                .frame(minWidth: 80)

            Picker("", selection: param.mode) {
                ForEach(ParameterMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 100)

            PostgresDataTypePicker(selection: param.dataType, prompt: "data type")
                .frame(minWidth: 80)

            TextField("", text: param.defaultValue, prompt: Text("default"))
                .textFieldStyle(.plain)
                .frame(minWidth: 60)
        }
    }
}
