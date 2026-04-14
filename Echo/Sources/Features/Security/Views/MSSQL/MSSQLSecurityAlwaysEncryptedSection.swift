import SwiftUI
import SQLServerKit

struct MSSQLSecurityAlwaysEncryptedSection: View {
    @Bindable var viewModel: DatabaseSecurityViewModel
    var onNewCMK: () -> Void
    var onNewCEK: () -> Void
    @Environment(EnvironmentState.self) private var environmentState

    enum SubSection: String, CaseIterable {
        case columnMasterKeys = "Column Master Keys"
        case columnEncryptionKeys = "Column Encryption Keys"
    }

    @State private var selectedSubSection: SubSection = .columnMasterKeys
    @State private var cmkSortOrder = [KeyPathComparator(\ColumnMasterKeyInfo.name)]
    @State private var cekSortOrder = [KeyPathComparator(\ColumnEncryptionKeyInfo.name)]
    @State private var showDropAlert = false
    @State private var pendingDropName: String?
    @State private var pendingDropType: SubSection?

    var body: some View {
        VStack(spacing: 0) {
            subSectionPicker
            switch selectedSubSection {
            case .columnMasterKeys:
                cmkTable
            case .columnEncryptionKeys:
                cekTable
            }
        }
        .alert("Drop Key?", isPresented: $showDropAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Drop", role: .destructive) {
                if let name = pendingDropName, let type = pendingDropType {
                    Task {
                        switch type {
                        case .columnMasterKeys:
                            await viewModel.dropColumnMasterKey(name: name)
                        case .columnEncryptionKeys:
                            await viewModel.dropColumnEncryptionKey(name: name)
                        }
                    }
                }
            }
        } message: {
            Text("Are you sure you want to drop \(pendingDropName ?? "")? This action cannot be undone.")
        }
    }

    private var subSectionPicker: some View {
        Picker(selection: $selectedSubSection) {
            ForEach(SubSection.allCases, id: \.self) { sub in
                Text(sub.rawValue).tag(sub)
            }
        } label: {
            EmptyView()
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 320)
        .padding(.vertical, SpacingTokens.xs)
    }

    // MARK: - Column Master Keys

    private var cmkTable: some View {
        Table(viewModel.columnMasterKeys.sorted(using: cmkSortOrder), selection: $viewModel.selectedCMKName, sortOrder: $cmkSortOrder) {
            TableColumn("Name", value: \.name) { cmk in
                Text(cmk.name)
                    .font(TypographyTokens.Table.name)
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
                    Button { scriptCreateCMK(name: name) } label: {
                        Label("CREATE", systemImage: "plus.square")
                    }
                    Button { scriptDropCMK(name: name) } label: {
                        Label("DROP", systemImage: "minus.square")
                    }
                }

                Divider()

                Button(role: .destructive) {
                    pendingDropName = name
                    pendingDropType = .columnMasterKeys
                    showDropAlert = true
                } label: {
                    Label("Drop Column Master Key", systemImage: "trash")
                }
            } else {
                Button {
                    Task { await viewModel.loadCurrentSection() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button { onNewCMK() } label: {
                    Label("New Column Master Key", systemImage: "key.fill")
                }
            }
        } primaryAction: { _ in }
    }

    // MARK: - Column Encryption Keys

    private var cekTable: some View {
        Table(viewModel.columnEncryptionKeys.sorted(using: cekSortOrder), selection: $viewModel.selectedCEKName, sortOrder: $cekSortOrder) {
            TableColumn("Name", value: \.name) { cek in
                Text(cek.name)
                    .font(TypographyTokens.Table.name)
            }
            .width(min: 100, ideal: 200)

            TableColumn("Created") { cek in
                if let date = cek.createDate {
                    Text(date)
                        .font(TypographyTokens.Table.date)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                } else {
                    Text("\u{2014}")
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .width(min: 80, ideal: 140)

            TableColumn("Modified") { cek in
                if let date = cek.modifyDate {
                    Text(date)
                        .font(TypographyTokens.Table.date)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                } else {
                    Text("\u{2014}")
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .width(min: 80, ideal: 140)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .contextMenu(forSelectionType: String.self) { selection in
            if let name = selection.first {
                Menu("Script as", systemImage: "scroll") {
                    Button { scriptDropCEK(name: name) } label: {
                        Label("DROP", systemImage: "minus.square")
                    }
                }

                Divider()

                Button(role: .destructive) {
                    pendingDropName = name
                    pendingDropType = .columnEncryptionKeys
                    showDropAlert = true
                } label: {
                    Label("Drop Column Encryption Key", systemImage: "trash")
                }
            } else {
                Button {
                    Task { await viewModel.loadCurrentSection() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button { onNewCEK() } label: {
                    Label("New Column Encryption Key", systemImage: "key")
                }
            }
        } primaryAction: { _ in }
    }

    // MARK: - Script Helpers

    private func scriptCreateCMK(name: String) {
        let n = escapeID(name)
        openScriptTab(sql: "CREATE COLUMN MASTER KEY \(n)\n    WITH (KEY_STORE_PROVIDER_NAME = N'MSSQL_CERTIFICATE_STORE',\n          KEY_PATH = N'CurrentUser/My/certificate_thumbprint');\nGO")
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
