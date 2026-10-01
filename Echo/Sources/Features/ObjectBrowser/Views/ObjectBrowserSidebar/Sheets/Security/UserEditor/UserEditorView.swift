import SwiftUI

struct UserEditorView: View {
    @Bindable var viewModel: UserEditorViewModel
    let session: ConnectionSession
    let onDismiss: () -> Void

    @State private var selectedPage: UserEditorPage? = .general
    @State private var navHistory = NavigationHistory<UserEditorPage>()

    private var userDisplayName: String {
        viewModel.userName.isEmpty ? "New User" : viewModel.userName
    }

    var body: some View {
        NavigationSplitView {
            List(UserEditorPage.allCases, selection: $selectedPage) { page in
                Label(page.title, systemImage: page.icon)
                    .tag(page)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
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
                        icon: "person.circle",
                        title: "Loading User Properties",
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
        .safeAreaInset(edge: .bottom) {
            if let error = viewModel.errorMessage {
                editorErrorBanner(error)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.errorMessage)
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
        guard let page = selectedPage else { return userDisplayName }
        if page == .general { return userDisplayName }
        return page.title
    }

    private var navigationSubtitleText: String {
        guard let page = selectedPage else { return "" }
        if page == .general { return "" }
        return userDisplayName
    }

    // MARK: - Page Content

    @ViewBuilder
    private var pageContent: some View {
        switch selectedPage {
        case .general:
            UserEditorGeneralPage(viewModel: viewModel, session: session)
        case .ownedSchemas:
            UserEditorOwnedSchemasPage(viewModel: viewModel)
        case .membership:
            UserEditorMembershipPage(viewModel: viewModel)
        case .securables:
            UserEditorSecurablesPage(viewModel: viewModel, session: session)
        case .extendedProperties:
            UserEditorExtendedPropertiesPage(viewModel: viewModel)
        case nil:
            EmptyView()
        }
    }
}
