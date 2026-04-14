import SwiftUI
import SQLServerKit

// MARK: - Files Page

extension MSSQLRestoreSidebarSheet {
    @ViewBuilder
    var filesPage: some View {
        if viewModel.fileRelocations.isEmpty {
            Section("File Relocation") {
                Text("No file information available. Use \"List Backup Sets\" on the General page first.")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        } else {
            Section {
                ForEach($viewModel.fileRelocations) { $entry in
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        Text(entry.logicalName)
                            .font(TypographyTokens.detail.weight(.medium))
                        TextField("", text: $entry.relocatedPath, prompt: Text(entry.originalPath))
                            .textFieldStyle(.plain)
                            .font(TypographyTokens.monospaced)
                    }
                }
            } header: {
                Text("File Relocation")
            } footer: {
                Text("Change the physical file paths if restoring to a server with a different directory layout.")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
    }
}
