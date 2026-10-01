import SwiftUI
import AppKit

extension DatabasesSettingsView {

    var pgToolStatusLabel: String {
        let customPath = settings.pgToolCustomPath
        if let tool = PostgresToolLocator.pgDumpURL(customPath: customPath) {
            let path = tool.path
            let isBundled = path.contains(".app/Contents/SharedSupport/PostgresTools")
            let prefix = isBundled ? "Bundled" : "Custom"
            return "\(prefix): \(tool.lastPathComponent) at \(path)"
        }
        return "pg_dump not found"
    }

    /// PostgreSQL-specific settings: managed console, backup tools.
    @ViewBuilder
    var postgresSettings: some View {
        Section("Managed Console") {
            PropertyRow(
                title: "Enable Postgres Console",
                info: "The Postgres Console is Echo's managed PostgreSQL console powered by the app's Postgres engine."
            ) {
                Toggle("", isOn: managedConsoleBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }

        Section("Scripts") {
            PropertyRow(
                title: "Continue after a failed statement",
                info: "A script stops at the first statement that fails, so later statements never run on a half-finished state. Turn this on to run the rest anyway, as psql does."
            ) {
                Toggle("", isOn: binding(for: \.postgresScriptsContinueAfterError))
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }

        Section("Backup & Restore Tools") {
            PropertyRow(
                title: "Tool Path",
                info: "By default, Echo uses bundled pg_dump and pg_restore. Override with a custom path to use a specific PostgreSQL version."
            ) {
                HStack {
                    TextField("", text: pgToolCustomPathBinding, prompt: Text("Bundled (default)"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                    Button("Browse") {
                        let panel = NSOpenPanel()
                        panel.title = "Select PostgreSQL Tools Directory"
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK, let url = panel.url {
                            pgToolCustomPathBinding.wrappedValue = url.path
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            HStack {
                Text(pgToolStatusLabel)
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
                Spacer()
            }
        }

    }
}
