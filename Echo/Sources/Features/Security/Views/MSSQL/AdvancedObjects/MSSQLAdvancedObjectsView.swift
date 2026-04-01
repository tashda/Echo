import SwiftUI

struct MSSQLAdvancedObjectsView: View {
    @Bindable var viewModel: MSSQLAdvancedObjectsViewModel
    @Environment(EnvironmentState.self) private var environmentState

    @State private var showNewCatalogSheet = false
    @State private var showNewIndexSheet = false
    @State private var showNewPublicationSheet = false
    @State private var showNewSubscriptionSheet = false
    @State private var showConfigureDistribution = false

    var body: some View {
        VStack(spacing: 0) {
            TabSectionToolbar {
                sectionPicker
            } controls: {
                toolbarControls
            }

            Divider()

            if !viewModel.isInitialized {
                TabInitializingPlaceholder(
                    icon: "puzzlepiece.extension",
                    title: "Loading Objects",
                    subtitle: "Fetching advanced object metadata\u{2026}"
                )
            } else {
                sectionContent
            }
        }
        .background(ColorTokens.Background.primary)
        .task { await viewModel.initialize() }
        .onChange(of: viewModel.selectedSection) { _, _ in
            guard viewModel.isInitialized else { return }
            viewModel.errorMessage = nil
            Task { await viewModel.loadCurrentSection() }
        }
        .sheet(isPresented: $showNewCatalogSheet) {
            NewFullTextCatalogSheet { name, isDefault, accentSensitive in
                await viewModel.createCatalog(name: name, isDefault: isDefault, accentSensitive: accentSensitive)
            } onCancel: {
                showNewCatalogSheet = false
            }
        }
        .sheet(isPresented: $showNewIndexSheet) {
            if let connSession = environmentState.sessionGroup.sessionForConnection(viewModel.connectionID) {
                NewFullTextIndexSheet(
                    catalogs: viewModel.ftCatalogs,
                    session: connSession,
                    onCreated: {
                        showNewIndexSheet = false
                        Task { await viewModel.loadFullText() }
                    },
                    onCancel: { showNewIndexSheet = false }
                )
            }
        }
        .sheet(isPresented: $showNewPublicationSheet) {
            if let connSession = environmentState.sessionGroup.sessionForConnection(viewModel.connectionID) {
                NewPublicationSheet(
                    databaseName: viewModel.databaseName,
                    session: connSession,
                    onCreated: { Task { await viewModel.loadReplication() } },
                    onDismiss: { showNewPublicationSheet = false }
                )
            }
        }
        .sheet(isPresented: $showNewSubscriptionSheet) {
            if let connSession = environmentState.sessionGroup.sessionForConnection(viewModel.connectionID) {
                NewSubscriptionSheet(
                    publications: viewModel.publications,
                    session: connSession,
                    onCreated: { Task { await viewModel.loadReplication() } },
                    onDismiss: { showNewSubscriptionSheet = false }
                )
            }
        }
        .sheet(isPresented: $showConfigureDistribution) {
            if let connSession = environmentState.sessionGroup.sessionForConnection(viewModel.connectionID) {
                ConfigureDistributionSheet(session: connSession) {
                    showConfigureDistribution = false
                    Task { await viewModel.loadReplication() }
                }
            }
        }
    }

    // MARK: - Toolbar

    private var sectionPicker: some View {
        HStack(spacing: SpacingTokens.sm) {
            Picker(selection: $viewModel.selectedSection) {
                ForEach(MSSQLAdvancedObjectsViewModel.Section.allCases, id: \.self) { section in
                    Text(section.rawValue).tag(section)
                }
            } label: { EmptyView() }
            .pickerStyle(.menu)
            .frame(maxWidth: 200)

            if viewModel.isLoadingCurrentSection {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private var toolbarControls: some View {
        switch viewModel.selectedSection {
        case .changeTracking, .cdc:
            EmptyView()
        case .fullTextSearch:
            Button { showNewCatalogSheet = true } label: {
                Label("New Catalog", systemImage: "plus")
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
        case .replication:
            if !viewModel.distributorConfigured {
                Button { showConfigureDistribution = true } label: {
                    Label("Configure Distribution", systemImage: "gearshape")
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
            } else {
                Button { showNewPublicationSheet = true } label: {
                    Label("New Publication", systemImage: "plus")
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var sectionContent: some View {
        VStack(spacing: 0) {
            if let error = viewModel.errorMessage {
                errorBanner(error)
            }

            switch viewModel.selectedSection {
            case .changeTracking:
                MSSQLChangeTrackingSection(viewModel: viewModel)
            case .cdc:
                MSSQLCDCSection(viewModel: viewModel)
            case .fullTextSearch:
                MSSQLFullTextSection(
                    viewModel: viewModel,
                    showNewCatalogSheet: $showNewCatalogSheet,
                    showNewIndexSheet: $showNewIndexSheet
                )
            case .replication:
                MSSQLReplicationSection(
                    viewModel: viewModel,
                    showNewPublicationSheet: $showNewPublicationSheet,
                    showNewSubscriptionSheet: $showNewSubscriptionSheet,
                    showConfigureDistribution: $showConfigureDistribution
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(ColorTokens.Status.warning)
            Text(message)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
            Spacer()
            Button("Dismiss") { viewModel.errorMessage = nil }
                .controlSize(.small)
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
        .background(ColorTokens.Background.secondary)
    }
}
