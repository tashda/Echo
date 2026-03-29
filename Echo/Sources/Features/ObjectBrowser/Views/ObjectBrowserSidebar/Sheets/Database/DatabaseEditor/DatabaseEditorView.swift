import SwiftUI
import SQLServerKit
import PostgresKit

struct DatabaseEditorView: View {
    @Bindable var viewModel: DatabaseEditorViewModel
    let session: ConnectionSession
    let onDismiss: () -> Void

    @State private var selectedPage: DatabaseEditorPage? = .general
    @State private var navHistory = NavigationHistory<DatabaseEditorPage>()

    var body: some View {
        NavigationSplitView {
            List(viewModel.pages, id: \.self, selection: $selectedPage) { page in
                Label(page.title, systemImage: page.icon)
                    .tag(page)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            Form {
                if !viewModel.isLoading && !isFullPageState {
                    pageContent
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .overlay {
                if viewModel.isLoading {
                    TabInitializingPlaceholder(
                        icon: "cylinder",
                        title: "Loading Properties",
                        subtitle: "Fetching database configuration\u{2026}"
                    )
                } else if isFullPageState {
                    fullPageView
                }
            }
            .id(selectedPage)
            .frame(minWidth: 440, minHeight: 400)
            .navigationTitle(navigationTitleText)
            .navigationSubtitle(navigationSubtitleText)
            .toolbarTitleDisplayMode(.automatic)
            .navigationHistoryToolbar($selectedPage, history: navHistory)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await applyChanges() }
                    } label: {
                        Label("Apply", systemImage: "arrow.right.circle")
                    }
                    .labelStyle(.iconOnly)
                    .disabled(!viewModel.isFormValid || viewModel.isSubmitting || !viewModel.hasChanges)
                    .help("Apply changes without closing")
                    .glassEffect(.regular.interactive())
                }
                .sharedBackgroundVisibility(.hidden)

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await saveAndClose() }
                    } label: {
                        Label("Save", systemImage: "checkmark")
                    }
                    .labelStyle(.iconOnly)
                    .disabled(!viewModel.isFormValid || viewModel.isSubmitting || !viewModel.hasChanges)
                    .help("Save and close")
                    .glassEffect(.regular.interactive())
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
        .task {
            viewModel.errorMessage = nil
            await viewModel.loadProperties(session: session)
        }
        .onChange(of: viewModel.didComplete) { _, completed in
            if completed { onDismiss() }
        }
        .onChange(of: selectedPage) { _, page in
            if let page {
                Task { await viewModel.ensurePageLoaded(page, session: session) }
            }
        }
        .overlay(alignment: .bottom) {
            if let error = viewModel.errorMessage {
                HStack(spacing: SpacingTokens.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(ColorTokens.Status.warning)
                    Text(error)
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .lineLimit(1)
                }
                .padding(SpacingTokens.sm)
                .background(.regularMaterial, in: .capsule)
                .padding(.bottom, SpacingTokens.sm)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    Task {
                        try? await Task.sleep(for: .seconds(5))
                        withAnimation { viewModel.errorMessage = nil }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.errorMessage)
    }

    // MARK: - Title

    private var navigationTitleText: String {
        guard let page = selectedPage else { return viewModel.databaseName }
        if page == .general { return viewModel.databaseName }
        return page.title
    }

    private var navigationSubtitleText: String {
        guard let page = selectedPage else { return "" }
        if page == .general { return "" }
        return viewModel.databaseName
    }

    // MARK: - Full Page States (rendered as overlay, outside the Form)

    /// Whether the current page should show a full-page state instead of form content.
    private var isFullPageState: Bool {
        switch selectedPage {
        case .mirroring where viewModel.isMSSQL:
            return viewModel.mirroringStatus == nil || viewModel.mirroringStatus?.isConfigured != true
        case .logShipping where viewModel.isMSSQL:
            return viewModel.logShippingConfig == nil
        default:
            return false
        }
    }

    @ViewBuilder
    private var fullPageView: some View {
        switch selectedPage {
        case .mirroring:
            ContentUnavailableView(
                "Mirroring Not Configured",
                systemImage: "arrow.left.arrow.right",
                description: Text("This database has not been configured for mirroring.")
            )
        case .logShipping:
            ContentUnavailableView(
                "Log Shipping Not Configured",
                systemImage: "shippingbox",
                description: Text("This database is not configured as a log shipping primary.")
            )
        default:
            EmptyView()
        }
    }

    // MARK: - Page Content

    @ViewBuilder
    private var pageContent: some View {
        switch selectedPage {
        case .general:
            if viewModel.isMSSQL, let props = viewModel.mssqlProps {
                mssqlGeneralPage(props)
            } else if viewModel.isPostgres, let props = viewModel.pgProps {
                postgresGeneralPage(props)
            }
        case .options:
            if viewModel.isMSSQL {
                mssqlOptionsPage()
            }
        case .files:
            if viewModel.isMSSQL {
                mssqlFilesPage()
            }
        case .queryStore:
            if viewModel.isMSSQL {
                mssqlQueryStorePage()
            }
        case .filegroups:
            if viewModel.isMSSQL {
                mssqlFilegroupsPage()
            }
        case .mirroring:
            if viewModel.isMSSQL {
                mssqlMirroringPage()
            }
        case .logShipping:
            if viewModel.isMSSQL {
                mssqlLogShippingPage()
            }
        case .scopedConfigurations:
            if viewModel.isMSSQL {
                mssqlScopedConfigurationsPage()
            }
        case .definition:
            if viewModel.isPostgres, let props = viewModel.pgProps {
                postgresDefinitionPage(props)
            }
        case .parameters:
            if viewModel.isPostgres {
                postgresParametersPage()
            }
        case .security:
            if viewModel.isPostgres {
                postgresSecurityPage()
            }
        case .defaultPrivileges:
            if viewModel.isPostgres {
                postgresDefaultPrivilegesPage()
            }
        case .statistics:
            EmptyView()
        case .sql:
            if viewModel.isPostgres {
                postgresSQLPage()
            }
        case nil:
            EmptyView()
        }
    }

    // MARK: - Actions

    private func applyChanges() async {
        viewModel.isSubmitting = true
        viewModel.errorMessage = nil
        do {
            try await viewModel.submitChanges(session: session)
            viewModel.takeSnapshot()
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
        viewModel.isSubmitting = false
    }

    private func saveAndClose() async {
        viewModel.isSubmitting = true
        viewModel.errorMessage = nil
        do {
            try await viewModel.submitChanges(session: session)
            viewModel.takeSnapshot()
            viewModel.didComplete = true
            onDismiss()
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
        viewModel.isSubmitting = false
    }

}
