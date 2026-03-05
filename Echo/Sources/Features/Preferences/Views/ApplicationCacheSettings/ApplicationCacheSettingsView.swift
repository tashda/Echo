import SwiftUI
import Foundation
import EchoSense

struct ApplicationCacheSettingsView: View {
    @Environment(ProjectStore.self) var projectStore
    @Environment(ConnectionStore.self) var connectionStore
    @Environment(TabStore.self) var tabStore
    
    @EnvironmentObject var environmentState: EnvironmentState
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var clipboardHistory: ClipboardHistoryStore

    @State var confirmDisableHistory = false
    @State var resultCacheUsage: UInt64 = 0
    @State var isRefreshingResultCache = false
    @State var autocompleteHistoryUsage: UInt64 = 0
    @State var isRefreshingAutocompleteHistory = false
    @State var usePerTypeStorageLimits = false

    var body: some View {
        Form {
            cacheManagementSection
            storageLimitsSection
            storageUsageSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .task {
            await refreshResultCacheUsage()
            await refreshAutocompleteHistoryUsage()
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
            workspaceTabToggleRow
            queryResultRetentionRow

            VStack(alignment: .leading, spacing: 4) {
                ToggleWithInfo(
                    title: "Enable clipboard history",
                    isOn: clipboardEnabledBinding,
                    description: "Echo stores recently copied queries and results locally for quick reuse. Data stays on this Mac."
                )

                if !clipboardHistory.isEnabled {
                    Text("History capture is disabled. Re-enable it to keep new copies.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .padding(.top, SpacingTokens.xxxs)
                }
            }
        }
    }

    var storageLimitsSection: some View {
        Section("Storage") {
            if !usePerTypeStorageLimits {
                LabeledContent {
                    Picker("", selection: resultCacheMaxBinding) {
                        ForEach([1, 2, 5, 10, 20], id: \.self) { gb in
                            Text("\(gb) GB").tag(gb * 1_024 * 1_024 * 1_024)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .controlSize(.regular)
                    .frame(minWidth: 120, idealWidth: 160, maxWidth: 200, alignment: .trailing)
                } label: {
                    Text("Maximum storage")
                }
            }

            Toggle("Set storage limits per cache type", isOn: $usePerTypeStorageLimits)
                .toggleStyle(.switch)

            if usePerTypeStorageLimits {
                LabeledContent {
                    Picker("", selection: resultCacheMaxBinding) {
                        ForEach([0.5, 1, 2, 5, 10], id: \.self) { gb in
                            Text("\(gb) GB").tag(Int(gb * 1_024 * 1_024 * 1_024))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .controlSize(.regular)
                    .frame(minWidth: 120, idealWidth: 160, maxWidth: 200, alignment: .trailing)
                } label: {
                    Text("Result Cache")
                }

                if clipboardHistory.isEnabled {
                    LabeledContent {
                        Picker("", selection: clipboardStorageLimitBinding) {
                            ForEach([0.5, 1, 2, 5, 10], id: \.self) { gb in
                                Text("\(gb) GB").tag(Int(gb * 1_024 * 1_024 * 1_024))
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .controlSize(.regular)
                        .frame(minWidth: 120, idealWidth: 160, maxWidth: 200, alignment: .trailing)
                    } label: {
                        Text("Clipboard History")
                    }
                }

                Text("EchoSense history size is managed automatically for now.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            unifiedStorageLocationRow
        }
    }

    private var storageUsageSection: some View {
        let usage = clipboardHistory.formattedUsageBreakdown()

        return Section("Cache Usage") {
            storageUsageRow(
                title: "Result Cache",
                usage: resultCacheUsage,
                isRefreshing: isRefreshingResultCache,
                onRefresh: { await refreshResultCacheUsage() },
                onClear: { clearResultCache() }
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
                    onClear: { clearClipboardHistory() },
                    usageBreakdown: usage
                )
            }
        }
    }
}
