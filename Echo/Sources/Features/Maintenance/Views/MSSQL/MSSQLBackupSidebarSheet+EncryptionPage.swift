import SwiftUI
import SQLServerKit

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
