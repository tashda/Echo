import SQLServerKit
import SwiftUI

extension MSSQLSecurityAlwaysEncryptedSection {
    var cmkTable: some View {
        Table(viewModel.columnMasterKeys.sorted(using: cmkSortOrder), selection: $viewModel.selectedCMKName, sortOrder: $cmkSortOrder) {
            TableColumn("Name", value: \.name) { cmk in
                Text(cmk.name).font(TypographyTokens.Table.name)
            }
            .width(min: 100, ideal: 180)

            TableColumn("Key Store Provider", value: \.keyStoreProviderName) { cmk in
                Text(cmk.keyStoreProviderName)
                    .font(TypographyTokens.Table.category)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 80, ideal: 160)

            TableColumn("Key Path", value: \.keyPath) { cmk in
                Text(cmk.keyPath)
                    .font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .width(min: 100, ideal: 200)

            TableColumn("Enclave") { cmk in
                Image(systemName: cmk.allowEnclaveComputations ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(cmk.allowEnclaveComputations ? ColorTokens.Status.success : ColorTokens.Text.tertiary)
            }
            .width(min: 50, ideal: 70)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .contextMenu(forSelectionType: String.self) { selection in
            if let name = selection.first {
                Menu("Script as", systemImage: "scroll") {
                    Button { scriptCreateCMK(name: name) } label: { Label("CREATE", systemImage: "plus.square") }
                    Button { scriptDropCMK(name: name) } label: { Label("DROP", systemImage: "minus.square") }
                }
                Divider()
                Button(role: .destructive) {
                    pendingDropName = name
                    pendingDropType = .columnMasterKeys
                    showDropAlert = true
                } label: { Label("Drop Column Master Key", systemImage: "trash") }
            } else {
                Button { Task { await viewModel.loadCurrentSection() } } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                Button { onNewCMK() } label: { Label("New Column Master Key", systemImage: "key.fill") }
            }
        } primaryAction: { _ in }
    }

    var cekTable: some View {
        Table(viewModel.columnEncryptionKeys.sorted(using: cekSortOrder), selection: $viewModel.selectedCEKName, sortOrder: $cekSortOrder) {
            TableColumn("Name", value: \.name) { cek in
                Text(cek.name).font(TypographyTokens.Table.name)
            }
            .width(min: 100, ideal: 200)

            TableColumn("Created") { cek in
                optionalDate(cek.createDate)
            }
            .width(min: 80, ideal: 140)

            TableColumn("Modified") { cek in
                optionalDate(cek.modifyDate)
            }
            .width(min: 80, ideal: 140)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .contextMenu(forSelectionType: String.self) { selection in
            if let name = selection.first {
                Menu("Script as", systemImage: "scroll") {
                    Button { scriptDropCEK(name: name) } label: { Label("DROP", systemImage: "minus.square") }
                }
                Divider()
                Button(role: .destructive) {
                    pendingDropName = name
                    pendingDropType = .columnEncryptionKeys
                    showDropAlert = true
                } label: { Label("Drop Column Encryption Key", systemImage: "trash") }
            } else {
                Button { Task { await viewModel.loadCurrentSection() } } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                Button { onNewCEK() } label: { Label("New Column Encryption Key", systemImage: "key") }
            }
        } primaryAction: { _ in }
    }

    @ViewBuilder
    private func optionalDate(_ date: String?) -> some View {
        if let date {
            Text(date)
                .font(TypographyTokens.Table.date)
                .foregroundStyle(ColorTokens.Text.tertiary)
        } else {
            Text("\u{2014}").foregroundStyle(ColorTokens.Text.tertiary)
        }
    }

    private func scriptCreateCMK(name: String) {
        let escapedName = escapeID(name)
        openScriptTab(sql: "CREATE COLUMN MASTER KEY \(escapedName)\n    WITH (KEY_STORE_PROVIDER_NAME = N'MSSQL_CERTIFICATE_STORE',\n          KEY_PATH = N'CurrentUser/My/certificate_thumbprint');\nGO")
    }

    private func scriptDropCMK(name: String) {
        openScriptTab(sql: "DROP COLUMN MASTER KEY \(escapeID(name));\nGO")
    }

    private func scriptDropCEK(name: String) {
        openScriptTab(sql: "DROP COLUMN ENCRYPTION KEY \(escapeID(name));\nGO")
    }

    private func escapeID(_ name: String) -> String {
        "[\(name.replacingOccurrences(of: "]", with: "]]"))]"
    }

    private func openScriptTab(sql: String) {
        if let session = environmentState.sessionGroup.sessionForConnection(viewModel.connectionID) {
            environmentState.openQueryTab(for: session, presetQuery: sql)
        }
    }
}
