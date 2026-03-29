import SwiftUI
import AppKit
import UniformTypeIdentifiers

extension SchemaDiffView {
    func exportMigrationSQL() {
        let sql = viewModel.generateMigrationSQLForFilteredDiffs()
        guard !sql.isEmpty else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = viewModel.migrationExportFilename
        panel.canCreateDirectories = true
        panel.prompt = "Export"

        panel.beginSheetModal(for: NSApp.keyWindow ?? NSApp.mainWindow!) { response in
            guard response == .OK, let url = panel.url else { return }
            try? sql.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
