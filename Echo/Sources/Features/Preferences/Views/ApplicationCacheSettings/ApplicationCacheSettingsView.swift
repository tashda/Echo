import SwiftUI
import Foundation
import EchoSense

struct ApplicationCacheSettingsView: View {
    @Environment(ProjectStore.self) var projectStore
    @Environment(ConnectionStore.self) var connectionStore
    @Environment(TabStore.self) var tabStore

    @Environment(EnvironmentState.self) var environmentState
    @Environment(AppState.self) var appState

    @State var resultCacheUsage: UInt64 = 0
    @State var isRefreshingResultCache = false
    @State var autocompleteHistoryUsage: UInt64 = 0
    @State var isRefreshingAutocompleteHistory = false
    @State var diagramCacheUsage: UInt64 = 0
    @State var isRefreshingDiagramCache = false
    @State var objectBrowserCacheUsage: UInt64 = 0
    @State var isRefreshingObjectBrowserCache = false

    var body: some View {
        Form {
            cacheManagementSection
            queryHistorySection
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
            await refreshObjectBrowserCacheUsage()
        }
    }

    private var cacheManagementSection: some View {
        Section("Cache Management") {
            PropertyRow(title: "Query result retention") {
                Picker("", selection: resultCacheRetentionBinding) {
                    ForEach(Self.retentionOptions, id: \.hours) { Text($0.label).tag($0.hours) }
                }.labelsHidden().pickerStyle(.menu)
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
                title: "Object Browser Cache",
                usage: objectBrowserCacheUsage,
                isRefreshing: isRefreshingObjectBrowserCache,
                onRefresh: { await refreshObjectBrowserCacheUsage() },
                onClear: { clearObjectBrowserCache() }
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
