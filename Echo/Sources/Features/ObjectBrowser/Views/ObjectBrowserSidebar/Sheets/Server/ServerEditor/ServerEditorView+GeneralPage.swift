import SwiftUI
import SQLServerKit

// MARK: - General Page

extension ServerEditorView {

    @ViewBuilder
    func generalPage() -> some View {
        if let info = viewModel.serverInfo {
            Section("Server") {
                readOnlyRow("Server Name", value: info.serverName)
                readOnlyRow("Product", value: info.product)
                readOnlyRow("Edition", value: info.edition)
                readOnlyRow("Version", value: info.productVersion)
                readOnlyRow("Product Level", value: info.productLevel)
                readOnlyRow("Engine Edition", value: "\(info.engineEdition)")
            }

            Section("Operating System") {
                readOnlyRow("Machine Name", value: info.machineName)
                readOnlyRow("Process ID", value: "\(info.processID)")
            }

            if let sys = viewModel.systemInfo {
                Section("Hardware") {
                    readOnlyRow("Processors", value: "\(sys.cpuCount)")
                    readOnlyRow("Sockets", value: "\(sys.socketCount)")
                    readOnlyRow("Cores per Socket", value: "\(sys.coresPerSocket)")
                    readOnlyRow("NUMA Nodes", value: "\(sys.numaNodeCount)")
                    readOnlyRow("Physical Memory", value: String(format: "%.1f GB", Double(sys.physicalMemoryMB) / 1024.0))
                    readOnlyRow("Max Worker Threads", value: "\(sys.maxWorkersCount)")
                    readOnlyRow("SQL Server Start Time", value: sys.sqlServerStartTime)
                }
            }

            Section("Configuration") {
                readOnlyRow("Collation", value: info.collation)
                readOnlyRow("Is Clustered", value: info.isClustered ? "Yes" : "No")
                readOnlyRow("Is HADR Enabled", value: info.isHadrEnabled ? "Yes" : "No")
                readOnlyRow("Authentication", value: info.isIntegratedSecurityOnly ? "Windows" : "Mixed")
            }

            Section("Default Paths") {
                readOnlyRow("Default Data Path", value: info.instanceDefaultDataPath)
                readOnlyRow("Default Log Path", value: info.instanceDefaultLogPath)
                readOnlyRow("Default Backup Path", value: info.instanceDefaultBackupPath)
            }

            if info.filestreamConfiguredLevel > 0 {
                Section("FILESTREAM") {
                    readOnlyRow("Configured Level", value: "\(info.filestreamConfiguredLevel)")
                    readOnlyRow("Effective Level", value: "\(info.filestreamEffectiveLevel)")
                    readOnlyRow("Share Name", value: info.filestreamShareName)
                }
            }
        }
    }

    // MARK: - Read-Only Row

    private func readOnlyRow(_ title: String, value: String) -> some View {
        PropertyRow(title: title) {
            Text(value)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
    }
}
