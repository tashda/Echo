import SwiftUI
import Foundation
import EchoSense

struct ApplicationCacheSettingsView: View {
    @Environment(ProjectStore.self) var projectStore
    @Environment(ConnectionStore.self) var connectionStore
    @Environment(TabStore.self) var tabStore

    @Environment(EnvironmentState.self) var environmentState
    @Environment(AppState.self) var appState
    @Environment(ClipboardHistoryStore.self) var clipboardHistory

    @State var confirmDisableHistory = false
    @State var resultCacheUsage: UInt64 = 0
    @State var isRefreshingResultCache = false
    @State var autocompleteHistoryUsage: UInt64 = 0
    @State var isRefreshingAutocompleteHistory = false
    @State var diagramCacheUsage: UInt64 = 0
    @State var isRefreshingDiagramCache = false

    var usePerTypeStorageLimits: Binding<Bool> {
        Binding(
            get: { projectStore.globalSettings.usePerTypeStorageLimits },
            set: { newValue in
                var settings = projectStore.globalSettings
                settings.usePerTypeStorageLimits = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    var body: some View {
        Form {
            cacheManagementSection
            storageLimitsSection
            storageUsageSection
            storageLocationSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .task {
            await refreshResultCacheUsage()
            await refreshAutocompleteHistoryUsage()
            await refreshDiagramCacheUsage()
        }
        .alert("Disable Clipboard History?", isPresented: $confirmDisableHistory) {
            Button("Disable", role: .destructive) {
                confirmDisableHistory = false
                clipboardHistory.setEnabled(false)
            }
            Button("Cancel", role: .cancel) {
                confirmDisableHistory = false
            }
        } message: {
            Text("Echo will immediately delete all saved clipboard items. This action cannot be undone.")
        }
    }

    private var cacheManagementSection: some View {
        Section("Cache Management") {
            SettingsRowWithInfo(
                title: "Keep tabs in memory",
                description: "Keeps each tab's editor and results view alive when switching. This speeds up tab changes at the cost of additional memory usage."
            ) {
                Toggle("", isOn: keepTabsBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            LabeledContent("Query result retention") {
                Picker("", selection: resultCacheRetentionBinding) {
                    ForEach(Self.retentionOptions, id: \.hours) { option in
                        Text(option.label).tag(option.hours)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(minWidth: 120, idealWidth: 160, maxWidth: 200, alignment: .trailing)
            }

            SettingsRowWithInfo(
                title: "Enable clipboard history",
                description: "Echo stores recently copied queries and results locally for quick reuse. Data stays on this Mac."
            ) {
                Toggle("", isOn: clipboardEnabledBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }
    }

    private var storageUsageSection: some View {
        Section("Cache Usage") {
            storageUsageRow(
                title: "Result Cache",
                usage: resultCacheUsage,
                isRefreshing: isRefreshingResultCache,
                onRefresh: { await refreshResultCacheUsage() },
                onClear: { clearResultCache() }
            )

            storageUsageRow(
                title: "Diagram Cache",
                usage: diagramCacheUsage,
                isRefreshing: isRefreshingDiagramCache,
                onRefresh: { await refreshDiagramCacheUsage() },
                onClear: { clearDiagramCache() }
            )

            storageUsageRow(
                title: "EchoSense History",
                usage: autocompleteHistoryUsage,
                isRefreshing: isRefreshingAutocompleteHistory,
                onRefresh: { await refreshAutocompleteHistoryUsage() },
                onClear: { clearAutocompleteHistory() }
            )

            if clipboardHistory.isEnabled {
                storageUsageRow(
                    title: "Clipboard History",
                    usage: UInt64(clipboardHistory.usage.totalBytes),
                    isRefreshing: false,
                    onRefresh: nil,
                    onClear: { clearClipboardHistory() }
                )
            }
        }
    }

    private var storageLocationSection: some View {
        Section {
            StorageLocationButton()
        }
    }

    // MARK: - Constants

    static let gb = 1_073_741_824

    static let retentionOptions: [(label: String, hours: Int)] = [
        ("Never", 0),
        ("1 hour", 1),
        ("6 hours", 6),
        ("12 hours", 12),
        ("24 hours", 24),
        ("3 days", 72),
        ("7 days", 168),
        ("14 days", 336),
        ("Forever", -1),
    ]

    static let unifiedStorageOptions: [(label: String, bytes: Int)] = [
        ("1 GB",  1 * gb),
        ("2 GB",  2 * gb),
        ("5 GB",  5 * gb),
        ("10 GB", 10 * gb),
        ("20 GB", 20 * gb),
    ]

    static let perTypeStorageOptions: [(label: String, bytes: Int)] = [
        ("512 MB", gb / 2),
        ("1 GB",   1 * gb),
        ("2 GB",   2 * gb),
        ("5 GB",   5 * gb),
        ("10 GB",  10 * gb),
    ]
}
