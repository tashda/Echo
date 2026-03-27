import SwiftUI
import SQLServerKit

// MARK: - Options Page

extension MSSQLRestoreSidebarSheet {
    var restoreOptionsPage: some View {
        Group {
            Section("Overwrite") {
                PropertyRow(
                    title: "Overwrite (REPLACE)",
                    info: "Allow restoring over an existing database even if the database name differs from the backup. Use with caution — this overwrites the target database."
                ) {
                    Toggle("", isOn: $viewModel.replace)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                PropertyRow(
                    title: "Close Connections",
                    info: "Set the database to SINGLE_USER mode before restoring, disconnecting all active sessions. Automatically restores MULTI_USER mode after the restore completes."
                ) {
                    Toggle("", isOn: $viewModel.closeConnections)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            Section("Access") {
                PropertyRow(
                    title: "Preserve Replication",
                    info: "Keep replication settings intact after restore. Without this, replication configuration is removed during restore."
                ) {
                    Toggle("", isOn: $viewModel.keepReplication)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                PropertyRow(
                    title: "Restricted Access",
                    info: "Restrict access to the restored database to members of db_owner, dbcreator, and sysadmin roles."
                ) {
                    Toggle("", isOn: $viewModel.restrictedUser)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            Section("Reliability") {
                PropertyRow(
                    title: "Checksum",
                    info: "Verify page checksums during restore. Detects corruption in the backup file."
                ) {
                    Toggle("", isOn: $viewModel.restoreChecksum)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                PropertyRow(
                    title: "Continue on Error",
                    info: "Continue restoring even if checksum errors are found. By default, restore stops on the first error."
                ) {
                    Toggle("", isOn: $viewModel.restoreContinueOnError)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }
        }
    }
}
