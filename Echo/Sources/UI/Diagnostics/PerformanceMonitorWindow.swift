import SwiftUI

struct PerformanceMonitorWindow: Scene {
    static let sceneID = "performance-monitor"

    var body: some Scene {
        Window("Performance Monitor", id: Self.sceneID) {
            PerformanceMonitorView()
                .environment(AppCoordinator.shared.projectStore)
                .environment(AppCoordinator.shared.connectionStore)
                .environment(AppCoordinator.shared.navigationStore)
                .environment(AppCoordinator.shared.tabStore)
                .environmentObject(AppCoordinator.shared.environmentState)
                .environmentObject(AppCoordinator.shared.appState)
                .environmentObject(AppCoordinator.shared.appearanceStore)
        }
        .defaultSize(width: 960, height: 620)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)
    }
}

private struct PerformanceMonitorView: View {
    @Environment(TabStore.self) private var tabStore
    @EnvironmentObject private var environmentState: EnvironmentState
    @EnvironmentObject private var appearanceStore: AppearanceStore
    @ObservedObject private var coordinator = AppCoordinator.shared

    private var queryTabs: [WorkspaceTab] {
        guard coordinator.isInitialized else { return [] }
        return tabStore.tabs.filter { $0.query != nil }
    }

    var body: some View {
        Group {
            if !coordinator.isInitialized {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Preparing live metrics...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ColorTokens.Background.primary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header

                        if queryTabs.isEmpty {
                            PerformanceMonitorEmptyState(
                                title: "No Query Tabs",
                                message: "Run a query to start capturing live performance metrics.",
                                systemImage: "table"
                            )
                            .frame(maxWidth: .infinity)
                        } else {
                            ForEach(queryTabs) { tab in
                                PerformanceMonitorRow(tab: tab)
                            }
                        }
                    }
                    .padding(.vertical, SpacingTokens.lg)
                    .padding(.horizontal, SpacingTokens.xl)
                }
                .background(ColorTokens.Background.primary)
            }
        }
        .preferredColorScheme(appearanceStore.effectiveColorScheme)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Live Query Performance")
                .font(.largeTitle.bold())
            Text("Monitor execution timelines, batch flow, and resource usage across open query tabs.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct PerformanceMonitorEmptyState: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(SpacingTokens.xl2)
    }
}

private struct PerformanceMonitorRow: View {
    @ObservedObject var tab: WorkspaceTab
    @EnvironmentObject private var appearanceStore: AppearanceStore

    var body: some View {
        Group {
            if let query = tab.query {
                PerformanceMonitorQueryContent(tab: tab, query: query)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text(tab.title)
                        .font(.headline)
                    Text("Performance metrics are only available for query tabs.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(SpacingTokens.md2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ColorTokens.Background.secondary)
                .shadow(
                    color: Color.black.opacity(appearanceStore.effectiveColorScheme == .dark ? 0.35 : 0.12),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
    }
}
