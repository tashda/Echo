import AppKit
import SwiftUI

extension DatabasesSettingsView {
    var mysqlToolStatusLabel: String {
        let customPath = settings.mysqlToolCustomPath
        let resolvedTools = [
            ("mysqldump", MySQLToolLocator.mysqldumpURL(customPath: customPath)),
            ("mysql", MySQLToolLocator.mysqlURL(customPath: customPath)),
            ("mysqlpump", MySQLToolLocator.mysqlpumpURL(customPath: customPath))
        ]
        let availableTools = resolvedTools.compactMap { tool -> String? in
            let (name, url) = tool
            guard let url else { return nil }
            return "\(name): \(url.path)"
        }

        if availableTools.isEmpty {
            return "MySQL command-line tools not found"
        }

        return availableTools.joined(separator: "  •  ")
    }

    @ViewBuilder
    var mySQLSettings: some View {
        Section("Backup & Restore Tools") {
            PropertyRow(
                title: "Tool Path",
                info: "Override the directory Echo uses to resolve mysqldump, mysql, and mysqlpump for MySQL backup and restore workflows."
            ) {
                HStack {
                    TextField("", text: mysqlToolCustomPathBinding, prompt: Text("Auto-detect (default)"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                    Button("Browse") {
                        let panel = NSOpenPanel()
                        panel.title = "Select MySQL Tools Directory"
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK, let url = panel.url {
                            mysqlToolCustomPathBinding.wrappedValue = url.path
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            HStack {
                Text(mysqlToolStatusLabel)
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
                Spacer()
            }
        }
    }
}
