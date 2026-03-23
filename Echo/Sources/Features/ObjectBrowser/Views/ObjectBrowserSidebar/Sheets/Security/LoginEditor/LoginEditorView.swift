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
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            Group {
                if viewModel.isLoadingGeneral {
                    VStack {
                        Spacer()
                        ProgressView("Loading login properties\u{2026}")
                        Spacer()
                    }
                } else {
                    Form {
                        pageContent
                    }
                    .formStyle(.grouped)
                    .scrollContentBackground(.hidden)
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
                    .disabled(!viewModel.isFormValid || viewModel.isSubmitting)
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
                    .disabled(!viewModel.isFormValid || viewModel.isSubmitting)
                    .help(viewModel.isEditing ? "Save and close" : "Create and close")
                    .glassEffect(.regular.interactive())
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
        .background(PocketSeparatorHider())
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
        guard let page = selectedPage else { return loginDisplayName }
        if page == .general { return loginDisplayName }
        return page.title
    }

    private var navigationSubtitleText: String {
        guard let page = selectedPage else { return "" }
        if page == .general { return "" }
        return loginDisplayName
    }

    // MARK: - Page Content

    @ViewBuilder
    private var pageContent: some View {
        switch selectedPage {
        case .general:
            LoginEditorGeneralPage(viewModel: viewModel)
        case .serverRoles:
            LoginEditorServerRolesPage(viewModel: viewModel)
        case .userMapping:
            LoginEditorUserMappingPage(viewModel: viewModel, session: session)
        case .securables:
            LoginEditorSecurablesPage(viewModel: viewModel)
        case .status:
            LoginEditorStatusPage(viewModel: viewModel)
        case nil:
            EmptyView()
        }
    }
}
