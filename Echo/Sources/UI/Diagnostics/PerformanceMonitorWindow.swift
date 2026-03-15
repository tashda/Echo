import SwiftUI

struct PerformanceMonitorWindow: Scene {
    static let sceneID = "performance-monitor"

    var body: some Scene {
        Window("Performance Monitor", id: Self.sceneID) {
            PerformanceMonitorView()
                .environment(AppDirector.shared.projectStore)
                .environment(AppDirector.shared.connectionStore)
                .environment(AppDirector.shared.navigationStore)
                .environment(AppDirector.shared.tabStore)
                .environment(AppDirector.shared.environmentState)
                .environment(AppDirector.shared.appState)
                .environment(AppDirector.shared.appearanceStore)
        }
        .defaultSize(width: 960, height: 620)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)
    }
}

private struct PerformanceMonitorView: View {
    @Environment(TabStore.self) private var tabStore
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppearanceStore.self) private var appearanceStore
    @Bindable private var coordinator = AppDirector.shared

    private var queryTabs: [WorkspaceTab] {
        guard coordinator.isInitialized else { return [] }
        return tabStore.tabs.filter { $0.query != nil }
    }

    var body: some View {
        Group {
            if !coordinator.isInitialized {
                VStack(spacing: SpacingTokens.md) {
                    ProgressView()
                    Text("Preparing live metrics...")
                        .font(TypographyTokens.footnote)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ColorTokens.Background.primary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: SpacingTokens.md) {
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
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("Live Query Performance")
                .font(TypographyTokens.hero.weight(.bold))
            Text("Monitor execution timelines, batch flow, and resource usage across open query tabs.")
                .font(TypographyTokens.subheadline)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
    }
}

struct PerformanceMonitorEmptyState: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: SpacingTokens.sm) {
            Image(systemName: systemImage)
                .font(TypographyTokens.hero.weight(.light))
                .foregroundStyle(ColorTokens.Text.secondary)
            Text(title)
                .font(TypographyTokens.headline)
            Text(message)
                .font(TypographyTokens.footnote)
                .foregroundStyle(ColorTokens.Text.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(SpacingTokens.xl2)
    }
}

private struct PerformanceMonitorRow: View {
    @Bindable var tab: WorkspaceTab
    @Environment(AppearanceStore.self) private var appearanceStore

    var body: some View {
        Group {
            if let query = tab.query {
                PerformanceMonitorQueryContent(tab: tab, query: query)
            } else {
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    Text(tab.title)
                        .font(TypographyTokens.headline)
                    Text("Performance metrics are only available for query tabs.")
                        .font(TypographyTokens.footnote)
                        .foregroundStyle(ColorTokens.Text.secondary)
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
