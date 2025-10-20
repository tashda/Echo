import SwiftUI
import Foundation
import EchoSense
#if os(macOS)
import AppKit
#endif

struct ApplicationCacheSettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var clipboardHistory: ClipboardHistoryStore
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var confirmDisableHistory = false
    @State private var resultCacheUsage: UInt64 = 0
    @State private var isRefreshingResultCache = false
    @State private var autocompleteHistoryUsage: UInt64 = 0
    @State private var isRefreshingAutocompleteHistory = false

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
            workspaceTabSection
            resultCacheSection
            autocompleteHistorySection

            Section("Clipboard History") {
                Toggle("Enable clipboard history", isOn: clipboardEnabledBinding(for: store))
                    .toggleStyle(.switch)

                Text("Echo stores recently copied queries and results locally for quick reuse. Data stays on this Mac.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if !store.isEnabled {
                    Text("History capture is disabled. Re-enable it to keep new copies.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
            }

            if store.isEnabled {
                storageLimitSection(for: store)
                storageLocationSection
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(themeManager.surfaceBackgroundColor)
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

    private var workspaceTabSection: some View {
        let tabs = appModel.tabManager.tabs
        let totalBytes = tabs.reduce(0) { $0 + $1.estimatedMemoryUsageBytes() }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .memory

        return Section("Workspace Tabs") {
            Toggle("Keep tabs in memory", isOn: keepTabsBinding)
                .toggleStyle(.switch)

            Text("Keeps each tab's editor and results view alive when switching. This speeds up tab changes at the cost of additional memory usage.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if tabs.isEmpty {
                Text("No tabs are currently open.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(tabs) { tab in
                        TabMemoryRow(
                            tab: tab,
                            formatter: formatter,
                            contextProvider: { tabMemoryContextLabel(for: $0) }
                        )
                    }

                    Divider()

                    HStack {
                        Text("Total for open tabs")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text(formatter.string(fromByteCount: Int64(totalBytes)))
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.top, 2)
                }
                .padding(.top, 6)
            }
        }
    }

    private var resultCacheSection: some View {
        Section("Result Cache") {
            cacheLocationRow

            Picker("Maximum storage", selection: resultCacheMaxBinding) {
                ForEach(storageOptions(for: appModel.globalSettings.resultSpoolMaxBytes), id: \.self) { value in
                    Text(ClipboardHistoryStore.formatByteCount(value)).tag(value)
                }
            }
            .frame(maxWidth: 320)

            Stepper(value: resultCacheRetentionBinding, in: 1...(24 * 14)) {
                let hours = appModel.globalSettings.resultSpoolRetentionHours
                let days = Double(hours) / 24.0
                let formattedDays = String(format: "%.1f", days)
                Text("Retention: \(hours) hour\(hours == 1 ? "" : "s") (~\(formattedDays) days)")
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Current usage")
                    Spacer()
                    if isRefreshingResultCache {
                        ProgressView()
                            .controlSize(.small)
                            .progressViewStyle(.circular)
                            .frame(width: 18, height: 18)
                            .frame(minWidth: 18, idealWidth: 18, maxWidth: 18, minHeight: 18, idealHeight: 18, maxHeight: 18)
                            .fixedSize()
                    } else {
                        Text(formatByteCount(resultCacheUsage))
                            .font(.system(size: 12, weight: .semibold))
                    }
                }

                Text("Echo stores streamed query results on disk so large result sets stay fast and light on memory. Change the limits above to tune cache size and automatic cleanup.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button("Clear Result Cache", role: .destructive) {
                clearResultCache()
            }
        }
        .task(id: appModel.globalSettings.resultSpoolCustomLocation) {
            await refreshResultCacheUsage()
        }
    }

    private var autocompleteHistorySection: some View {
        Section("Autocomplete History") {
            HStack {
                Text("Stored suggestions")
                Spacer()
                if isRefreshingAutocompleteHistory {
                    ProgressView()
                        .controlSize(.small)
                        .progressViewStyle(.circular)
                        .frame(width: 18, height: 18)
                        .frame(minWidth: 18, idealWidth: 18, maxWidth: 18, minHeight: 18, idealHeight: 18, maxHeight: 18)
                        .fixedSize()
                } else {
                    Text(formatByteCount(autocompleteHistoryUsage))
                        .font(.system(size: 12, weight: .semibold))
                }
            }

            Text("Echo remembers the autocomplete suggestions you accept so the most relevant tables, columns, joins, and snippets appear first. History is stored locally on this Mac.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Clear Autocomplete History", role: .destructive) {
                    clearAutocompleteHistory()
                }
                .buttonStyle(.bordered)

                Button("Refresh Size") {
                    Task { await refreshAutocompleteHistoryUsage() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)

                Spacer()
            }
            .padding(.top, 6)
        }
    }

    private func storageLimitSection(for store: ClipboardHistoryStore) -> some View {
        let usage = store.formattedUsageBreakdown()
        let options = storageOptions(for: store.storageLimit)

        return Section("Storage Limit") {
            Picker("Maximum storage", selection: storageLimitBinding(for: store)) {
                ForEach(options, id: \.self) { value in
                    Text(ClipboardHistoryStore.formatByteCount(value))
                        .tag(value)
                }
            }
            .frame(maxWidth: 320)

            VStack(alignment: .leading, spacing: 8) {
                Text("Clipboard items persist until the storage limit is reached or you uninstall Echo.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                usageView(usage)
            }
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var cacheLocationRow: some View {
        let url = resolvedResultCacheURL()
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Cache location")
                Spacer()
                Text(url.path)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(2)
            }

#if os(macOS)
            HStack(spacing: 12) {
                Button("Change…") { presentResultCacheLocationPicker(current: url) }
                Button("Reveal in Finder") { revealResultCacheLocation(url) }
                if appModel.globalSettings.resultSpoolCustomLocation != nil {
                    Button("Use Default") {
                        Task { await appModel.updateGlobalEditorDisplay { $0.resultSpoolCustomLocation = nil } }
                    }
                }
            }
#endif
        }
    }

    private var resultCacheMaxBinding: Binding<Int> {
        Binding(
            get: { appModel.globalSettings.resultSpoolMaxBytes },
            set: { newValue in
                Task { await appModel.updateGlobalEditorDisplay { $0.resultSpoolMaxBytes = max(256 * 1_024 * 1_024, newValue) } }
                Task { await refreshResultCacheUsage() }
            }
        )
    }

    private var resultCacheRetentionBinding: Binding<Int> {
        Binding(
            get: { appModel.globalSettings.resultSpoolRetentionHours },
            set: { newValue in
                Task { await appModel.updateGlobalEditorDisplay { $0.resultSpoolRetentionHours = max(1, newValue) } }
            }
        )
    }

    private func resolvedResultCacheURL() -> URL {
        if let custom = appModel.globalSettings.resultSpoolCustomLocation,
           !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(fileURLWithPath: (custom as NSString).expandingTildeInPath, isDirectory: true)
        }
        return ResultSpoolManager.defaultRootDirectory()
    }

    private func refreshResultCacheUsage() async {
        let shouldContinue = await MainActor.run { () -> Bool in
            if isRefreshingResultCache { return false }
            isRefreshingResultCache = true
            return true
        }
        guard shouldContinue else { return }
        let bytes = await appModel.resultSpoolManager.currentUsageBytes()
        await MainActor.run {
            self.resultCacheUsage = bytes
            self.isRefreshingResultCache = false
        }
    }

    private func clearResultCache() {
        Task {
            await appModel.resultSpoolManager.clearAll()
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

    private func formatByteCount(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }

#if os(macOS)
    private func presentResultCacheLocationPicker(current: URL) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.directoryURL = current
        panel.title = "Select Result Cache Location"
        if panel.runModal() == .OK, let selected = panel.url {
            Task { await appModel.updateGlobalEditorDisplay { $0.resultSpoolCustomLocation = selected.path } }
            Task { await refreshResultCacheUsage() }
        }
    }

    private func revealResultCacheLocation(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
#endif

    private var keepTabsBinding: Binding<Bool> {
        Binding(
            get: { appModel.globalSettings.keepTabsInMemory },
            set: { newValue in
                guard appModel.globalSettings.keepTabsInMemory != newValue else { return }
                Task { await appModel.updateGlobalEditorDisplay { $0.keepTabsInMemory = newValue } }
            }
        )
    }

private func tabMemoryContextLabel(for tab: WorkspaceTab) -> String {
        switch tab.kind {
        case .query:
            if let query = tab.query {
                if query.isExecuting {
                    return "Query (executing)"
                }
                let rowCount = max(query.rowProgress.totalReported, query.rowProgress.materialized)
                if rowCount > 0 {
                    return "Query results • \(rowCount) row\(rowCount == 1 ? "" : "s")"
                }
                return "Query editor"
            }
            return "Query editor"
        case .structure:
            if let editor = tab.structureEditor {
                let columnCount = editor.columns.count
                return "Structure • \(columnCount) column\(columnCount == 1 ? "" : "s")"
            }
            return "Structure editor"
        case .diagram:
            if let diagram = tab.diagram {
                let tableCount = diagram.nodes.count
                return "Diagram • \(tableCount) table\(tableCount == 1 ? "" : "s")"
            }
            return "Diagram"
        }
    }

    private var storageLocationSection: some View {
        Section("Storage Location") {
            Button(action: openHistoryFolder) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(historyDirectoryDisplayPath)
                            .font(.system(size: 12, weight: .semibold))
                            .textSelection(.enabled)

                        Text("Open this folder in Finder to inspect or remove files manually.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
    }

    private var historyDirectoryURL: URL {
        let fm = FileManager.default
        let baseSupport = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return baseSupport
            .appendingPathComponent("Echo", isDirectory: true)
            .appendingPathComponent("ClipboardHistory", isDirectory: true)
    }

    private var historyDirectoryDisplayPath: String {
        let fullPath = historyDirectoryURL.path
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        if fullPath.hasPrefix(homePath) {
            let suffix = fullPath.dropFirst(homePath.count)
            return "~" + suffix
        }
        return fullPath
    }

    private func openHistoryFolder() {
        let url = historyDirectoryURL
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
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

    private func storageLimitBinding(for store: ClipboardHistoryStore) -> Binding<Int> {
        Binding(
            get: { store.storageLimit },
            set: { store.updateStorageLimit($0) }
        )
    }

    private func storageOptions(for limit: Int) -> [Int] {
        var options = baseStorageOptions
        if !options.contains(limit) {
            options.append(limit)
            options.sort()
        }
        return options
    }

    private func usageView(_ usageBreakdown: (total: String, query: String, grid: String)) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent("Used Total") {
                Text(usageBreakdown.total)
                    .monospacedDigit()
            }

            LabeledContent("Queries") {
                Text(usageBreakdown.query)
                    .monospacedDigit()
            }

            LabeledContent("Grid Data") {
                Text(usageBreakdown.grid)
                    .monospacedDigit()
            }
        }
    }
}

private struct TabMemoryRow: View {
    @ObservedObject var tab: WorkspaceTab
    let formatter: ByteCountFormatter
    let contextProvider: (WorkspaceTab) -> String

    var body: some View {
        let bytes = tab.estimatedMemoryUsageBytes()

        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tab.title.isEmpty ? "Untitled" : tab.title)
                    .font(.system(size: 13, weight: .semibold))
                Text(contextProvider(tab))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            Text(formatter.string(fromByteCount: Int64(bytes)))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
    }
}
