import SwiftUI
import SQLServerKit

struct ServerEditorView: View {
    @Bindable var viewModel: ServerEditorViewModel
    let session: ConnectionSession
    let onDismiss: () -> Void

    @State private var selectedPage: ServerEditorPage? = .general
    @State private var navHistory = NavigationHistory<ServerEditorPage>()

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
                if !viewModel.isLoading {
                    pageContent
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .overlay {
                if viewModel.isLoading {
                    TabInitializingPlaceholder(
                        icon: "server.rack",
                        title: "Loading Server Properties",
                        subtitle: "Fetching server configuration\u{2026}"
                    )
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
                        Task { await viewModel.apply(session: session) }
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
                        Task { await viewModel.saveAndClose(session: session) }
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
        .background(PocketSeparatorHider())
        .background(UnsavedChangesGuard(
            hasChanges: viewModel.hasChanges,
            onDiscard: onDismiss
        ))
        .task {
            viewModel.errorMessage = nil
            await viewModel.loadProperties(session: session)
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
        guard let page = selectedPage else { return "Server Properties" }
        if page == .general { return "Server Properties" }
        return page.title
    }

    private var navigationSubtitleText: String {
        guard let page = selectedPage else { return "" }
        if page == .general { return "" }
        return viewModel.serverInfo?.serverName ?? ""
    }

    // MARK: - Page Content

    @ViewBuilder
    private var pageContent: some View {
        switch selectedPage {
        case .general: generalPage()
        case .memory: memoryPage()
        case .processors: processorsPage()
        case .security: securityPage()
        case .connections: connectionsPage()
        case .databaseSettings: databaseSettingsPage()
        case .advanced: advancedPage()
        case .startupParameters: startupParametersPage()
        case nil: EmptyView()
        }
    }
}
