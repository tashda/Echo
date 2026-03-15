import SwiftUI
import SQLServerKit

struct RestoreSheet: View {
    @State var viewModel: RestoreViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            contentArea
            Divider()
            footerBar
        }
        .frame(minWidth: 600, minHeight: 460)
        .frame(idealWidth: 660, idealHeight: 540)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Label("Restore Database", systemImage: "arrow.counterclockwise.circle")
                .font(TypographyTokens.prominent.weight(.semibold))
            Spacer()
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.sm)
    }

    // MARK: - Content

    private var contentArea: some View {
        Form {
            sourceSection
            backupSetsSection
            backupFilesSection
            targetSection
            resultSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var sourceSection: some View {
        Section("Source") {
            TextField("Backup file path on server", text: $viewModel.diskPath)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("List Backup Sets") {
                    Task { await viewModel.listBackupSets() }
                }
                .disabled(!viewModel.canListSets)
            }

            if viewModel.isLoadingSets {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Reading backup file\u{2026}")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

            if let error = viewModel.loadError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Status.error)
            }
        }
    }

    @ViewBuilder
    private var backupSetsSection: some View {
        if !viewModel.backupSets.isEmpty {
            Section("Backup Sets") {
                backupSetsTable
            }
        }
    }

    private var backupSetsTable: some View {
        Table(viewModel.backupSets) {
            TableColumn("Position") { set in
                Text("\(set.id + 1)")
                    .font(TypographyTokens.detail)
            }
            .width(min: 50, ideal: 60)

            TableColumn("Type") { set in
                Text(set.backupTypeDescription)
                    .font(TypographyTokens.detail)
            }
            .width(min: 60, ideal: 80)

            TableColumn("Database") { set in
                Text(set.databaseName)
                    .font(TypographyTokens.detail)
            }
            .width(min: 80, ideal: 120)

            TableColumn("Size") { set in
                Text(set.formattedSize)
                    .font(TypographyTokens.detail)
            }
            .width(min: 60, ideal: 80)

            TableColumn("Name") { set in
                Text(set.backupName ?? "")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 80, ideal: 140)
        }
        .frame(minHeight: 80, maxHeight: 140)
    }

    @ViewBuilder
    private var backupFilesSection: some View {
        if !viewModel.backupFiles.isEmpty {
            Section("Files in Backup") {
                ForEach(viewModel.backupFiles) { file in
                    HStack {
                        Text(file.logicalName)
                            .font(TypographyTokens.detail)
                        Spacer()
                        Text(file.typeDescription)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }
            }
        }
    }

    private var targetSection: some View {
        Section("Target") {
            TextField("Database Name", text: $viewModel.databaseName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text("File Number")
                Spacer()
                TextField("", value: $viewModel.fileNumber, format: .number)
                    .frame(width: 60)
                    .multilineTextAlignment(.trailing)
            }

            Toggle("Recover database (WITH RECOVERY)", isOn: $viewModel.withRecovery)

            if !viewModel.withRecovery {
                Text("NORECOVERY leaves the database in a restoring state, allowing additional backups to be applied.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        switch viewModel.phase {
        case .completed(let messages):
            Section("Result") {
                if messages.isEmpty {
                    Label("Restore completed successfully.", systemImage: "checkmark.circle")
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
                Text("Restoring\u{2026}")
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
            Button("Restore") { Task { await viewModel.execute() } }
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.canExecute)
        }
        .padding(SpacingTokens.md)
    }
}
