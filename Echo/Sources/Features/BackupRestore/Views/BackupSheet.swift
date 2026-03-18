import SwiftUI
import SQLServerKit

struct BackupSheet: View {
    @State var viewModel: BackupViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            contentArea
            Divider()
            footerBar
        }
        .frame(minWidth: 520, minHeight: 380)
        .frame(idealWidth: 560, idealHeight: 420)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Label("Back Up Database", systemImage: "externaldrive.badge.timemachine")
                .font(TypographyTokens.prominent.weight(.semibold))
            Spacer()
            Text(viewModel.databaseName)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.sm)
    }

    // MARK: - Content

    private var contentArea: some View {
        Form {
            Section("Database") {
                PropertyRow(title: "Name") {
                    TextField("", text: $viewModel.databaseName)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("Backup Type") {
                PropertyRow(title: "Type") {
                    Picker("", selection: $viewModel.backupType) {
                        ForEach(SQLServerBackupType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
            }

            Section("Destination") {
                PropertyRow(
                    title: "Path on server",
                    info: "Path must be accessible to the SQL Server service account."
                ) {
                    TextField("", text: $viewModel.diskPath)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("Options") {
                PropertyRow(title: "Backup Name") {
                    TextField("", text: $viewModel.backupName)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
                
                PropertyRow(title: "Compression") {
                    Toggle("", isOn: $viewModel.compression)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                
                PropertyRow(title: "Copy-Only") {
                    Toggle("", isOn: $viewModel.copyOnly)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            resultSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var resultSection: some View {
        switch viewModel.phase {
        case .completed(let messages):
            Section("Result") {
                if messages.isEmpty {
                    Label("Backup completed successfully.", systemImage: "checkmark.circle")
                        .foregroundStyle(ColorTokens.Status.success)
                        .font(TypographyTokens.formDescription)
                } else {
                    ForEach(messages, id: \.self) { msg in
                        Text(msg)
                            .font(TypographyTokens.formDescription)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }
            }
        case .failed(let message):
            Section("Result") {
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(ColorTokens.Status.error)
                    .font(TypographyTokens.formDescription)
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            if viewModel.isRunning {
                ProgressView()
                    .controlSize(.small)
                Text("Backing up\u{2026}")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            Spacer()
            if viewModel.isRunning {
                Button("Cancel") { viewModel.cancel() }
                    .buttonStyle(.bordered)
            }
            Button("Close") { onDismiss() }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                .disabled(viewModel.isRunning)
            Button("Back Up") { Task { await viewModel.execute() } }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.canExecute)
        }
        .padding(SpacingTokens.md)
    }
}
