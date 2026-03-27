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
