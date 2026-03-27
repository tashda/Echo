import SwiftUI

struct DataExportSheet: View {
    @State var viewModel: DataExportViewModel
    let onDismiss: () -> Void

    var body: some View {
        SheetLayoutCustomFooter(title: "Export Data") {
            formContent
        } footer: {
            if let status = viewModel.statusMessage {
                Text(status)
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(viewModel.isError ? ColorTokens.Status.error : ColorTokens.Text.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button("Close") { onDismiss() }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                .disabled(viewModel.isExporting)
            if viewModel.canExport {
                Button("Export") { Task { await viewModel.executeExport() } }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Export") {}
                    .buttonStyle(.bordered)
                    .disabled(true)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .frame(minWidth: 520, minHeight: 400)
        .frame(idealWidth: 580, idealHeight: 460)
    }

    // MARK: - Form

    private var formContent: some View {
        Form {
            sourceSection

            Section("Format") {
                PropertyRow(title: "Output Format") {
                    Picker("", selection: $viewModel.format) {
                        ForEach(DataExportFormat.allCases) { fmt in
                            Text(fmt.rawValue).tag(fmt)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                if viewModel.supportsDelimitedOptions {
                    PropertyRow(title: "Custom Delimiter") {
                        TextField("", text: $viewModel.customDelimiter, prompt: Text("Leave blank for default"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 80)
                    }

                    PropertyRow(title: "Include Header") {
                        Toggle("", isOn: $viewModel.includeHeader)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }

                PropertyRow(title: "Encoding") {
                    TextField("", text: $viewModel.encoding, prompt: Text("UTF8"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("Destination") {
                PropertyRow(title: "Output File") {
                    HStack(spacing: SpacingTokens.xs) {
                        Text(viewModel.outputPath.isEmpty ? "No file selected" : viewModel.outputPath)
                            .font(TypographyTokens.formValue)
                            .foregroundStyle(viewModel.outputPath.isEmpty ? ColorTokens.Text.placeholder : ColorTokens.Text.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Browse") { viewModel.selectOutputFile() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            }

            if !viewModel.generatedSQL.isEmpty {
                SQLPreviewSection(sql: viewModel.generatedSQL)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var sourceSection: some View {
        Section("Source") {
            if viewModel.isResultSetExport {
                PropertyRow(title: "Results") {
                    Text("Current Query Results")
                        .font(TypographyTokens.formValue)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            } else {
                if viewModel.showsSchemaField {
                    PropertyRow(title: "Schema") {
                        TextField("", text: $viewModel.schema, prompt: Text(viewModel.schemaPlaceholder))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }
                PropertyRow(title: "Table") {
                    TextField("", text: $viewModel.tableName, prompt: Text("e.g. users"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }

}
