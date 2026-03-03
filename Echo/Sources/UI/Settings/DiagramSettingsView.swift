import SwiftUI
import Foundation

struct DiagramSettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var cacheUsage: UInt64 = 0
    @State private var isRefreshingUsage = false

    private let cacheOptions: [Int] = [
        128 * 1_024 * 1_024,
        256 * 1_024 * 1_024,
        512 * 1_024 * 1_024,
        1 * 1_024 * 1_024 * 1_024,
        2 * 1_024 * 1_024 * 1_024,
        5 * 1_024 * 1_024 * 1_024
    ]

    var body: some View {
        Form {
            prefetchSection
            refreshSection
            cacheSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .task {
            await refreshUsage()
        }
        .task(id: appModel.globalSettings.diagramCacheMaxBytes) {
            await refreshUsage()
        }
    }

    private var prefetchSection: some View {
        Section("Prefetching") {
            Picker("Diagram prefetch", selection: prefetchBinding) {
                ForEach(DiagramPrefetchMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)

            Picker("Background refresh", selection: refreshCadenceBinding) {
                ForEach(DiagramRefreshCadence.allCases, id: \.self) { cadence in
                    Text(cadence.displayName).tag(cadence)
                }
            }
            .frame(maxWidth: 360)

            Text("Echo can warm diagram data in the background for faster opens. Prefetching is optional so large databases do not fetch unused metadata.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        }
    }

    private var refreshSection: some View {
        Section("Refresh & Rendering") {
            Toggle("Verify diagram data before refresh", isOn: verifyBinding)
                .toggleStyle(.switch)

            Toggle("Render relationships in large diagrams", isOn: renderRelationshipsBinding)
                .toggleStyle(.switch)

            Text("Disable relationship rendering if diagrams with thousands of edges feel heavy; you can still re-enable it on demand.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        }
    }

    private var cacheSection: some View {
        Section("Cache") {
            Picker("Maximum cache size", selection: cacheLimitBinding) {
                ForEach(cacheOptions, id: \.self) { value in
                    Text(formatByteCount(value)).tag(value)
                }
            }
            .frame(maxWidth: 320)

            HStack {
                Text("Current usage")
                Spacer()
                if isRefreshingUsage {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(formatByteCount(cacheUsage))
                        .font(.system(size: 12, weight: .semibold))
                }
            }

            HStack(spacing: 12) {
                Button("Refresh Usage") {
                    Task { await refreshUsage() }
                }
                Button("Clear Diagram Cache", role: .destructive) {
                    Task { await clearCache() }
                }
            }
        }
    }

    private var prefetchBinding: Binding<DiagramPrefetchMode> {
        Binding(
            get: { appModel.globalSettings.diagramPrefetchMode },
            set: { newValue in
                Task { await appModel.updateGlobalEditorDisplay { $0.diagramPrefetchMode = newValue } }
            }
        )
    }

    private var refreshCadenceBinding: Binding<DiagramRefreshCadence> {
        Binding(
            get: { appModel.globalSettings.diagramRefreshCadence },
            set: { newValue in
                Task { await appModel.updateGlobalEditorDisplay { $0.diagramRefreshCadence = newValue } }
            }
        )
    }

    // Toggle: Verify cached diagram data before refreshing.
    private var verifyBinding: Binding<Bool> {
        Binding(
            get: { appModel.globalSettings.diagramVerifyBeforeRefresh },
            set: { newValue in
                Task { await appModel.updateGlobalEditorDisplay { $0.diagramVerifyBeforeRefresh = newValue } }
            }
        )
    }

    // Toggle: Render relationships in very large diagrams.
    private var renderRelationshipsBinding: Binding<Bool> {
        Binding(
            get: { appModel.globalSettings.diagramRenderRelationshipsForLargeDiagrams },
            set: { newValue in
                Task { await appModel.updateGlobalEditorDisplay { $0.diagramRenderRelationshipsForLargeDiagrams = newValue } }
            }
        )
    }

    private var cacheLimitBinding: Binding<Int> {
        Binding(
            get: { appModel.globalSettings.diagramCacheMaxBytes },
            set: { newValue in
                Task { await appModel.updateGlobalEditorDisplay { $0.diagramCacheMaxBytes = max(64 * 1_024 * 1_024, newValue) } }
            }
        )
    }

    private func refreshUsage() async {
        await MainActor.run { isRefreshingUsage = true }
        let usage = await appModel.diagramCacheManager.currentUsageBytes()
        await MainActor.run {
            cacheUsage = usage
            isRefreshingUsage = false
        }
    }

    private func clearCache() async {
        await appModel.diagramCacheManager.removeAll()
        await refreshUsage()
    }

    private func formatByteCount(_ count: Int) -> String {
        formatByteCount(UInt64(count))
    }

    private func formatByteCount(_ count: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(count))
    }
}
