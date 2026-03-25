import SwiftUI
import SQLServerKit

// MARK: - Media Page

extension MSSQLBackupSidebarSheet {
    var mediaPage: some View {
        Section("Media Set") {
            PropertyRow(
                title: "Overwrite Media",
                info: "Overwrite the backup file instead of appending. When off (NOINIT), new backup sets are appended to the existing file."
            ) {
                Toggle("", isOn: $viewModel.initMedia)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            PropertyRow(
                title: "Format Media",
                info: "Write a new media header on the backup file, effectively erasing all existing backup sets. Use when starting a new media set."
            ) {
                Toggle("", isOn: $viewModel.formatMedia)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            PropertyRow(
                title: "Media Set Name",
                info: "A label for the media set. If specified with FORMAT, the name is written to the media header. Without FORMAT, this is informational."
            ) {
                TextField("", text: $viewModel.mediaName, prompt: Text("e.g. Weekly Backups"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}

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

// MARK: - Encryption Page

extension MSSQLBackupSidebarSheet {
    var encryptionPage: some View {
        Section("Backup Encryption") {
            PropertyRow(
                title: "Enable Encryption",
                info: "Encrypt the backup using a server certificate or asymmetric key. The certificate must already exist on the SQL Server instance. Requires Enterprise Edition or Standard with backup compression."
            ) {
                Toggle("", isOn: $viewModel.encryptionEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            if viewModel.encryptionEnabled {
                PropertyRow(
                    title: "Algorithm",
                    info: "The encryption algorithm. AES_256 is recommended for most scenarios. TRIPLE_DES_3KEY is available for legacy compatibility."
                ) {
                    Picker("", selection: $viewModel.encryptionAlgorithm) {
                        ForEach(SQLServerBackupEncryptionAlgorithm.allCases, id: \.self) { algo in
                            Text(algo.rawValue).tag(algo)
                        }
                    }
                    .labelsHidden()
                }

                PropertyRow(
                    title: "Server Certificate",
                    info: "The name of the server certificate to use for encryption. The certificate must already be created on the SQL Server instance using CREATE CERTIFICATE."
                ) {
                    TextField("", text: $viewModel.encryptionCertificate, prompt: Text("e.g. BackupEncryptCert"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }
}

