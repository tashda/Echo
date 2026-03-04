import SwiftUI
import Foundation

struct DiagramSettingsView: View {
    @Environment(ProjectStore.self) private var projectStore
    @EnvironmentObject private var environmentState: EnvironmentState
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
        .task(id: projectStore.globalSettings.diagramCacheMaxBytes) {
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
            get: { projectStore.globalSettings.diagramPrefetchMode },
            set: { newValue in
                var settings = projectStore.globalSettings
                settings.diagramPrefetchMode = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    private var refreshCadenceBinding: Binding<DiagramRefreshCadence> {
        Binding(
            get: { projectStore.globalSettings.diagramRefreshCadence },
            set: { newValue in
                var settings = projectStore.globalSettings
                settings.diagramRefreshCadence = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    // Toggle: Verify cached diagram data before refreshing.
    private var verifyBinding: Binding<Bool> {
        Binding(
            get: { projectStore.globalSettings.diagramVerifyBeforeRefresh },
            set: { newValue in
                var settings = projectStore.globalSettings
                settings.diagramVerifyBeforeRefresh = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    // Toggle: Render relationships in very large diagrams.
    private var renderRelationshipsBinding: Binding<Bool> {
        Binding(
            get: { projectStore.globalSettings.diagramRenderRelationshipsForLargeDiagrams },
            set: { newValue in
                var settings = projectStore.globalSettings
                settings.diagramRenderRelationshipsForLargeDiagrams = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    private var cacheLimitBinding: Binding<Int> {
        Binding(
            get: { projectStore.globalSettings.diagramCacheMaxBytes },
            set: { newValue in
                var settings = projectStore.globalSettings
                settings.diagramCacheMaxBytes = max(64 * 1_024 * 1_024, newValue)
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    private func refreshUsage() async {
        await MainActor.run { isRefreshingUsage = true }
        let usage = await environmentState.diagramCacheManager.currentUsageBytes()
        await MainActor.run {
            cacheUsage = usage
            isRefreshingUsage = false
        }
    }

    private func clearCache() async {
        await environmentState.diagramCacheManager.removeAll()
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
