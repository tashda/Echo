import SwiftUI

struct LoginEditorView: View {
    @Bindable var viewModel: LoginEditorViewModel
    let session: ConnectionSession
    let onDismiss: () -> Void

    @State private var selectedPage: LoginEditorPage? = .general
    @State private var navHistory = NavigationHistory<LoginEditorPage>()

    private var loginDisplayName: String {
        viewModel.loginName.isEmpty ? "New Login" : viewModel.loginName
    }

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
                if !viewModel.isLoadingGeneral && !isPageLoading {
                    pageContent
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .overlay {
                if viewModel.isLoadingGeneral || isPageLoading {
                    TabInitializingPlaceholder(
                        icon: pageLoadingIcon,
                        title: pageLoadingTitle,
                        subtitle: pageLoadingSubtitle
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
        .inspector(isPresented: .constant(showInspector)) {
            LoginEditorUserMappingInspector(viewModel: viewModel, session: session)
                .inspectorColumnWidth(min: 220, ideal: 260, max: 320)
        }
        .background(PocketSeparatorHider())
        .background(UnsavedChangesGuard(
            hasChanges: viewModel.hasChanges,
            onDiscard: onDismiss
        ))
        .task {
            viewModel.errorMessage = nil
            await viewModel.loadAllData(session: session)
        }
        .onChange(of: selectedPage) { _, page in
            if let page {
                Task { await viewModel.ensurePageLoaded(page, session: session) }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let error = viewModel.errorMessage {
                editorErrorBanner(error)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.errorMessage)
    }

    // MARK: - Inspector

    private var showInspector: Bool {
        selectedPage == .userMapping && viewModel.selectedMappingDatabase != nil
    }

    // MARK: - Error Banner

    @ViewBuilder
    private func editorErrorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: SpacingTokens.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(ColorTokens.Status.error)
                .imageScale(.large)
            VStack(alignment: .leading, spacing: 2) {
                Text("Couldn't save")
                    .font(TypographyTokens.standard.weight(.semibold))
                Text(message)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button {
                viewModel.errorMessage = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .imageScale(.large)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(SpacingTokens.sm)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(ColorTokens.Status.error.opacity(0.25), lineWidth: 1)
        )
        .padding(.horizontal, SpacingTokens.md)
        .padding(.bottom, SpacingTokens.sm)
    }

    // MARK: - Title

    private var navigationTitleText: String {
        guard let page = selectedPage else { return loginDisplayName }
        if page == .general { return loginDisplayName }
        return page.title
    }

    private var navigationSubtitleText: String {
        guard let page = selectedPage else { return "" }
        if page == .general { return "" }
        return loginDisplayName
    }

    // MARK: - Per-Page Loading

    private var isPageLoading: Bool {
        switch selectedPage {
        case .serverRoles: return viewModel.isLoadingRoles
        case .userMapping: return viewModel.isLoadingMappings
        case .securables: return viewModel.isLoadingSecurables
        default: return false
        }
    }

    private var pageLoadingIcon: String {
        if viewModel.isLoadingGeneral { return "person.circle" }
        switch selectedPage {
        case .serverRoles: return "shield"
        case .userMapping: return "externaldrive.connected.to.line.below"
        case .securables: return "lock.shield"
        default: return "person.circle"
        }
    }

    private var pageLoadingTitle: String {
        if viewModel.isLoadingGeneral { return "Loading Login Properties" }
        switch selectedPage {
        case .serverRoles: return "Loading Server Roles"
        case .userMapping: return "Loading Database Mappings"
        case .securables: return "Loading Server Permissions"
        default: return "Loading"
        }
    }

    private var pageLoadingSubtitle: String {
        "Fetching data from server\u{2026}"
    }

    // MARK: - Page Content

    @ViewBuilder
    private var pageContent: some View {
        switch selectedPage {
        case .general:
            LoginEditorGeneralPage(viewModel: viewModel, session: session)
        case .serverRoles:
            LoginEditorServerRolesPage(viewModel: viewModel)
        case .userMapping:
            LoginEditorUserMappingPage(viewModel: viewModel, session: session)
        case .securables:
            LoginEditorSecurablesPage(viewModel: viewModel)
        case nil:
            EmptyView()
        }
    }
}
