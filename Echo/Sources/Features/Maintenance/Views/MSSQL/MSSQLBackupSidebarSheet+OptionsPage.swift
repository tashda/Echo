import SwiftUI
import SQLServerKit

// MARK: - Options Page

extension MSSQLBackupSidebarSheet {
    var optionsPage: some View {
        Group {
            Section("Reliability") {
                PropertyRow(
                    title: "Compression",
                    info: "Compress the backup to reduce file size and I/O. Increases CPU usage on the server during backup."
                ) {
                    Toggle("", isOn: $viewModel.compression)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                PropertyRow(
                    title: "Copy-Only",
                    info: "Creates a backup that does not affect the normal backup sequence. Use for ad-hoc backups that should not disrupt differential or log chains."
                ) {
                    Toggle("", isOn: $viewModel.copyOnly)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                PropertyRow(
                    title: "Checksum",
                    info: "Verify page checksums during backup. Detects I/O errors and torn pages. Recommended for production backups."
                ) {
                    Toggle("", isOn: $viewModel.checksum)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                PropertyRow(
                    title: "Continue on Error",
                    info: "Continue the backup even if checksum errors are detected. By default, backup stops on the first error."
                ) {
                    Toggle("", isOn: $viewModel.continueOnError)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            Section("Verification") {
                PropertyRow(
                    title: "Verify After Backup",
                    info: "Automatically runs RESTORE VERIFYONLY after the backup completes. Confirms the backup file is readable and structurally valid."
                ) {
                    Toggle("", isOn: $viewModel.verifyAfterBackup)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            Section("Expiration") {
                PropertyRow(
                    title: "Set Expiration Date",
                    info: "Marks the backup as expired after this date. SQL Server will not prevent overwriting expired backups. This is advisory — it does not auto-delete."
                ) {
                    Toggle("", isOn: $viewModel.useExpireDate)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                if viewModel.useExpireDate {
                    PropertyRow(title: "Expires On") {
                        DatePicker("", selection: $viewModel.expireDate, displayedComponents: [.date])
                            .labelsHidden()
                    }
                }
            }
        }
    }
}
