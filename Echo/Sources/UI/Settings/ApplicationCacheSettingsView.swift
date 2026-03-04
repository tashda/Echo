import SwiftUI
import Foundation
import EchoSense
#if os(macOS)
import AppKit
#endif

struct ApplicationCacheSettingsView: View {
    @Environment(ProjectStore.self) private var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(TabStore.self) private var tabStore
    
    @EnvironmentObject private var workspaceSessionStore: WorkspaceSessionStore
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var clipboardHistory: ClipboardHistoryStore
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var confirmDisableHistory = false
    @State private var resultCacheUsage: UInt64 = 0
    @State private var isRefreshingResultCache = false
    @State private var autocompleteHistoryUsage: UInt64 = 0
    @State private var isRefreshingAutocompleteHistory = false
    @State private var usePerTypeStorageLimits = false

    private let baseStorageOptions: [Int] = [
        256 * 1_024 * 1_024,
        512 * 1_024 * 1_024,
        1 * 1_024 * 1_024 * 1_024,
        2 * 1_024 * 1_024 * 1_024,
        5 * 1_024 * 1_024 * 1_024,
        10 * 1_024 * 1_024 * 1_024
    ]

    var body: some View {
        let store = clipboardHistory

        Form {
            // Group: Workspace Memory, Query Results, Clipboard History
            cacheManagementSection(for: store)
            storageLimitsSection
            storageUsageSection(for: store)
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
                store.setEnabled(false)
            }

            Button("Cancel", role: .cancel) {
                confirmDisableHistory = false
            }
        } message: {
            Text("Echo will immediately delete all saved clipboard items. This action cannot be undone.")
        }
    }

    // MARK: - Cache Management

    private func cacheManagementSection(for store: ClipboardHistoryStore) -> some View {
        Section("Cache Management") {
            workspaceTabToggleRow
            queryResultRetentionRow

            VStack(alignment: .leading, spacing: 4) {
                ToggleWithInfo(
                    title: "Enable clipboard history",
                    isOn: clipboardEnabledBinding(for: store),
                    description: "Echo stores recently copied queries and results locally for quick reuse. Data stays on this Mac."
                )

                if !store.isEnabled {
                    Text("History capture is disabled. Re-enable it to keep new copies.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
            }
        }
    }

    private var resultCacheMaxBinding: Binding<Int> {
        Binding(
            get: { projectStore.globalSettings.resultSpoolMaxBytes },
            set: { newValue in
                var settings = projectStore.globalSettings
                settings.resultSpoolMaxBytes = max(256 * 1_024 * 1_024, newValue)
                Task { 
                    try? await projectStore.updateGlobalSettings(settings)
                    await refreshResultCacheUsage()
                }
            }
        )
    }

    private var resultCacheRetentionBinding: Binding<Int> {
        Binding(
            get: { projectStore.globalSettings.resultSpoolRetentionHours },
            set: { newValue in
                var settings = projectStore.globalSettings
                settings.resultSpoolRetentionHours = max(1, newValue)
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    private var keepTabsBinding: Binding<Bool> {
        Binding(
            get: { projectStore.globalSettings.keepTabsInMemory },
            set: { newValue in
                guard projectStore.globalSettings.keepTabsInMemory != newValue else { return }
                var settings = projectStore.globalSettings
                settings.keepTabsInMemory = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    private var storageLimitsSection: some View {
        let store = clipboardHistory

        return Section("Storage") {
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

                if store.isEnabled {
                    LabeledContent {
                        Picker("", selection: storageLimitBinding(for: store)) {
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

    private func storageUsageSection(for store: ClipboardHistoryStore) -> some View {
        let usage = store.formattedUsageBreakdown()

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

            if store.isEnabled {
                storageUsageRow(
                    title: "Clipboard History",
                    usage: UInt64(store.usage.totalBytes),
                    isRefreshing: false,
                    onRefresh: nil,
                    onClear: { clearClipboardHistory() },
                    usageBreakdown: usage
                )
            }
        }
    }

    private var workspaceTabToggleRow: some View {
        ToggleWithInfo(
            title: "Keep tabs in memory",
            isOn: keepTabsBinding,
            description: "Keeps each tab's editor and results view alive when switching. This speeds up tab changes at the cost of additional memory usage."
        )
    }

    private var queryResultRetentionRow: some View {
        Stepper(value: resultCacheRetentionBinding, in: 1...(24 * 14)) {
            let hours = projectStore.globalSettings.resultSpoolRetentionHours
            let days = Double(hours) / 24.0
            let formattedDays = String(format: "%.1f", days)
            Text("Query Result Retention: \(hours) hour\(hours == 1 ? "" : "s") (~\(formattedDays) days)")
        }
    }

    private func storageOptions(for limit: Int) -> [Int] {
        var options = baseStorageOptions
        if !options.contains(limit) {
            options.append(limit)
            options.sort()
        }
        return options
    }

    private func storageLimitBinding(for store: ClipboardHistoryStore) -> Binding<Int> {
        Binding(
            get: { store.storageLimit },
            set: { store.updateStorageLimit($0) }
        )
    }

    private func clearClipboardHistory() {
        clipboardHistory.clearHistory()
    }

    private func clipboardEnabledBinding(for store: ClipboardHistoryStore) -> Binding<Bool> {
        Binding(
            get: { store.isEnabled },
            set: { newValue in
                if newValue {
                    store.setEnabled(true)
                } else {
                    confirmDisableHistory = true
                }
            }
        )
    }

    private var unifiedStorageLocationRow: some View {
        UnifiedStorageLocationRow()
    }

    private func storageUsageRow(
        title: String,
        usage: UInt64,
        isRefreshing: Bool,
        onRefresh: (() async -> Void)?,
        onClear: @escaping () -> Void,
        usageBreakdown: (total: String, query: String, grid: String)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                HStack(spacing: 12) {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                            .progressViewStyle(.circular)
                            .frame(width: 16, height: 16)
                    } else {
                        Text(formatByteCount(usage))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }

                    if let onRefresh = onRefresh {
                        Button(action: { Task { await onRefresh() } }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: onClear) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let breakdown = usageBreakdown {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Usage Breakdown")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("Queries:")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text(breakdown.query)
                            .font(.system(size: 10, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Grid Data:")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text(breakdown.grid)
                            .font(.system(size: 10, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatByteCount(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func refreshResultCacheUsage() async {
        let shouldContinue = await MainActor.run { () -> Bool in
            if isRefreshingResultCache { return false }
            isRefreshingResultCache = true
            return true
        }
        guard shouldContinue else { return }
        let bytes = await workspaceSessionStore.resultSpoolManager.currentUsageBytes()
        await MainActor.run {
            self.resultCacheUsage = bytes
            self.isRefreshingResultCache = false
        }
    }

    private func clearResultCache() {
        Task {
            await workspaceSessionStore.resultSpoolManager.clearAll()
            await refreshResultCacheUsage()
        }
    }

    private func clearAutocompleteHistory() {
        SQLAutoCompletionHistoryStore.shared.reset()
        autocompleteHistoryUsage = 0
    }

    private func refreshAutocompleteHistoryUsage() async {
        let shouldContinue = await MainActor.run { () -> Bool in
            if isRefreshingAutocompleteHistory { return false }
            isRefreshingAutocompleteHistory = true
            return true
        }
        guard shouldContinue else { return }

        let usage = SQLAutoCompletionHistoryStore.shared.currentUsageBytes()
        await MainActor.run {
            autocompleteHistoryUsage = usage
            isRefreshingAutocompleteHistory = false
        }
    }
}

private struct UnifiedStorageLocationRow: View {
    private var storageLocation: URL {
        let fm = FileManager.default
        let baseSupport = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return baseSupport.appendingPathComponent("Echo", isDirectory: true)
    }

    private func displayPath(_ path: String) -> String {
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(homePath) {
            let suffix = path.dropFirst(homePath.count)
            return "~" + suffix
        }
        return path
    }

    var body: some View {
        LabeledContent {
            Button(action: { NSWorkspace.shared.activateFileViewerSelecting([storageLocation]) }) {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("Storage Location")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)

                Text(displayPath(storageLocation.path))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }
}

private struct ToggleWithInfo: View {
    let title: String
    @Binding var isOn: Bool
    let description: String
    @State private var showInfoPopover = false

    var body: some View {
        HStack {
            Toggle(title, isOn: $isOn)
                .toggleStyle(.switch)

            Spacer()

            Button(action: { showInfoPopover.toggle() }) {
                Image(systemName: "info.circle")
                    .imageScale(.medium)
                    .font(.system(size: 13, weight: .regular))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .popover(isPresented: $showInfoPopover,
                     attachmentAnchor: .rect(.bounds),
                     arrowEdge: .trailing) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .frame(width: 240)
                .background(Color(.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}
