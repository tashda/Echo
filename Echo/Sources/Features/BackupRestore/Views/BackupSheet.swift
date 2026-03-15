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
                TextField("Database Name", text: $viewModel.databaseName)
                    .textFieldStyle(.roundedBorder)
            }

            Section("Backup Type") {
                Picker("Type", selection: $viewModel.backupType) {
                    ForEach(SQLServerBackupType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Destination") {
                TextField("File path on server", text: $viewModel.diskPath)
                    .textFieldStyle(.roundedBorder)

                Text("Path must be accessible to the SQL Server service account.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            Section("Options") {
                TextField("Backup Name", text: $viewModel.backupName)
                    .textFieldStyle(.roundedBorder)
                Toggle("Compression", isOn: $viewModel.compression)
                Toggle("Copy-Only Backup", isOn: $viewModel.copyOnly)
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
                        .font(TypographyTokens.detail)
                } else {
                    ForEach(messages, id: \.self) { msg in
                        Text(msg)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }
            }
        case .failed(let message):
            Section("Result") {
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(ColorTokens.Status.error)
                    .font(TypographyTokens.detail)
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
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            Spacer()
            if viewModel.isRunning {
                Button("Cancel") { viewModel.cancel() }
            }
            Button("Close") { onDismiss() }
                .keyboardShortcut(.cancelAction)
                .disabled(viewModel.isRunning)
            Button("Back Up") { Task { await viewModel.execute() } }
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.canExecute)
        }
        .padding(SpacingTokens.md)
    }
}
