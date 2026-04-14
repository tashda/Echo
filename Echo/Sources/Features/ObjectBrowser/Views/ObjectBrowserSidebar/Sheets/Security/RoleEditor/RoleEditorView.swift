import SwiftUI

struct RoleEditorView: View {
    @Bindable var viewModel: RoleEditorViewModel
    let session: ConnectionSession
    let onDismiss: () -> Void

    @State private var selectedPage: RoleEditorPage? = .general
    @State private var navHistory = NavigationHistory<RoleEditorPage>()

    private var roleDisplayName: String {
        viewModel.roleName.isEmpty ? "New Role" : viewModel.roleName
    }

    var body: some View {
        NavigationSplitView {
            List(RoleEditorPage.allCases, selection: $selectedPage) { page in
                Label(page.title, systemImage: page.icon)
                    .tag(page)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            Form {
                if !viewModel.isLoadingGeneral {
                    pageContent
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .overlay {
                if viewModel.isLoadingGeneral {
                    TabInitializingPlaceholder(
                        icon: "shield.lefthalf.filled",
                        title: "Loading Role Properties",
                        subtitle: "Fetching data from server\u{2026}"
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
                    .help(viewModel.isEditing ? "Save and close" : "Create and close")
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
            await viewModel.loadGeneralData(session: session)
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
        guard let page = selectedPage else { return roleDisplayName }
        if page == .general { return roleDisplayName }
        return page.title
    }

    private var navigationSubtitleText: String {
        guard let page = selectedPage else { return "" }
        if page == .general { return "" }
        return roleDisplayName
    }

    // MARK: - Page Content

    @ViewBuilder
    private var pageContent: some View {
        switch selectedPage {
        case .general:
            RoleEditorGeneralPage(viewModel: viewModel)
        case .membership:
            RoleEditorMembershipPage(viewModel: viewModel)
        case .securables:
            RoleEditorSecurablesPage(viewModel: viewModel, session: session)
        case nil:
            EmptyView()
        }
    }
}
