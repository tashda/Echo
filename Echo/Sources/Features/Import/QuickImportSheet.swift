import SwiftUI
import SQLServerKit
import UniformTypeIdentifiers

struct QuickImportSheet: View {
    @Bindable var viewModel: QuickImportViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showFilePicker = false
    
    var body: some View {
        SheetLayoutCustomFooter(title: "Import Flat File") {
            if viewModel.isImporting {
                importingView
            } else if viewModel.fileURL == nil {
                fileSelectionPrompt
            } else {
                importSettingsContent
            }
        } footer: {
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)

            Spacer()

            if viewModel.fileURL != nil && !viewModel.isImporting {
                Button("Change File...") { showFilePicker = true }

                if !viewModel.tableName.isEmpty {
                    Button("Import") { viewModel.startImport() }
                        .buttonStyle(.bordered)
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Import") {}
                        .buttonStyle(.bordered)
                        .disabled(true)
                        .keyboardShortcut(.defaultAction)
                }
            }

            if viewModel.statusMessage == "Import complete." {
                Button("Finish") { dismiss() }
                    .buttonStyle(.bordered)
            }
        }
        .frame(width: 700, height: 600)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .text],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.fileURL = url
                    viewModel.parseFile()
                }
            case .failure(let error):
                print("File selection error: \(error)")
            }
        }
    }
    
    private var fileSelectionPrompt: some View {
        ContentUnavailableView {
            Label("No File Selected", systemImage: "doc.badge.plus")
        } description: {
            Text("Select a CSV or TSV file to begin the import process.")
        } actions: {
            Button("Select File...") { showFilePicker = true }
                .buttonStyle(.bordered)
        }
    }
    
    private var importSettingsContent: some View {
        VStack(spacing: 0) {
            Form {
                Section("Table Settings") {
                    HStack {
                        TextField("Schema", text: $viewModel.schema)
                        TextField("Table Name", text: $viewModel.tableName)
                    }
                    Picker("Delimiter", selection: $viewModel.delimiter) {
                        ForEach(CSVDelimiter.allCases) { delim in
                            Text(delim.displayName).tag(delim)
                        }
                    }
                    .onChange(of: viewModel.delimiter) { viewModel.parseFile() }
                    
                    Toggle("First row has headers", isOn: $viewModel.firstRowHasHeaders)
                        .onChange(of: viewModel.firstRowHasHeaders) { viewModel.parseFile() }
                }
            }
            .formStyle(.grouped)
            .frame(height: 150)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 0) {
                Text("Review Schema Inference")
                    .font(TypographyTokens.headline)
                    .padding(SpacingTokens.sm)
                
                Table(viewModel.inferences) {
                    TableColumn("Column Name") { inf in
                        Text(inf.name)
                    }
                    TableColumn("Data Type") { inf in
                        Text(inf.dataType)
                            .foregroundStyle(.secondary)
                    }
                    TableColumn("Nullable") { inf in
                        Text(inf.isNullable ? "Yes" : "No")
                    }
                }
            }
        }
    }
    
    private var importingView: some View {
        VStack(spacing: SpacingTokens.md) {
            ProgressView(value: viewModel.progress)
                .progressViewStyle(.linear)
            Text(viewModel.statusMessage)
                .font(TypographyTokens.detail)
        }
        .padding(SpacingTokens.xl)
    }
    
}
