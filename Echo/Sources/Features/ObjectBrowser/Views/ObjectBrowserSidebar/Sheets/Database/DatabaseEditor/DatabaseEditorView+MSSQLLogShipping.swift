import SwiftUI
import SQLServerKit

// MARK: - Log Shipping Page

extension DatabaseEditorView {

    @ViewBuilder
    func mssqlLogShippingPage() -> some View {
        if let config = viewModel.logShippingConfig {
            Section("Primary Database") {
                PropertyRow(title: "Database") {
                    Text(config.primaryDatabase)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                PropertyRow(title: "Backup Directory") {
                    Text(config.backupDirectory)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .textSelection(.enabled)
                }
                PropertyRow(title: "Backup Share") {
                    Text(config.backupShare.isEmpty ? "Not configured" : config.backupShare)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .textSelection(.enabled)
                }
                PropertyRow(title: "Backup Retention") {
                    Text("\(config.backupRetentionPeriodMinutes) minutes")
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                PropertyRow(title: "Backup Compression") {
                    Text(config.backupCompression ? "Enabled" : "Disabled")
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                PropertyRow(title: "Last Backup") {
                    Text(config.lastBackupDate ?? "Never")
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

            if let monitor = config.monitorServer {
                Section("Monitor Server") {
                    PropertyRow(title: "Server") {
                        Text(monitor)
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .textSelection(.enabled)
                    }
                    PropertyRow(title: "Security Mode") {
                        Text(config.monitorServerSecurityMode == 0 ? "Windows Authentication" : "SQL Server Authentication")
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }
            }

            Section("Secondary Databases") {
                if config.secondaries.isEmpty {
                    Text("No secondary databases configured")
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .font(TypographyTokens.formDescription)
                } else {
                    ForEach(config.secondaries, id: \.secondaryDatabase) { secondary in
                        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                            Text("\(secondary.secondaryServer).\(secondary.secondaryDatabase)")
                                .font(TypographyTokens.body)
                            HStack(spacing: SpacingTokens.md) {
                                Label(secondary.lastCopiedDate ?? "Never copied", systemImage: "doc.on.doc")
                                Label(secondary.lastRestoredDate ?? "Never restored", systemImage: "arrow.counterclockwise")
                            }
                            .font(TypographyTokens.caption)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                        }
                    }
                }
            }
        }
    }
}
