import SwiftUI

struct AboutWindow: View {
    @Environment(AppearanceStore.self) private var appearanceStore
    @State private var selectedDependencyID: String? = "about-overview"

    private var versionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    private var selectedDependency: AboutDependency? {
        AboutMetadata.dependencies.first { $0.id == selectedDependencyID }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedDependencyID) {
                aboutOverviewSection
                dependencySection
            }
            .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 320)
            .listStyle(.sidebar)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                    heroSection
                    linkSection
                    if let selectedDependency {
                        dependencyDetailCard(for: selectedDependency)
                    }
                }
                .padding(SpacingTokens.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(ColorTokens.Background.primary)
            .navigationTitle("About Echo")
            .toolbarTitleDisplayMode(.automatic)
        }
        .preferredColorScheme(appearanceStore.effectiveColorScheme)
        .accentColor(appearanceStore.accentColor)
        .background(AboutWindowConfigurator())
    }

    private var aboutOverviewSection: some View {
        Section("Overview") {
            Label("About Echo", systemImage: "app.badge")
                .tag("about-overview")
            Label("Open Source Notices", systemImage: "doc.text")
                .tag(AboutMetadata.dependencies.first?.id)
        }
    }

    private var dependencySection: some View {
        Section("Packages") {
            ForEach(AboutMetadata.dependencies) { dependency in
                Label(dependency.name, systemImage: "shippingbox")
                    .tag(dependency.id)
            }
        }
    }

    private var heroSection: some View {
        AboutHeroCard(versionString: versionString, buildNumber: buildNumber)
    }

    private var linkSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text("Links")
                .font(TypographyTokens.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: SpacingTokens.sm) {
                ForEach(AboutMetadata.quickLinks) { link in
                    AboutLinkCard(link: link)
                }
            }
        }
    }
}
