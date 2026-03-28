import SwiftUI
import SQLServerKit

struct PermissionManagerView: View {
    @Bindable var viewModel: PermissionManagerViewModel
    let session: ConnectionSession
    let onDismiss: () -> Void

    @State private var selectedPage: PermissionManagerPage? = .securables
    @State private var navHistory = NavigationHistory<PermissionManagerPage>()

    private var principalDisplayName: String {
        viewModel.selectedPrincipalName.isEmpty ? "Permission Manager" : viewModel.selectedPrincipalName
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                principalPicker
                Divider()
                pageList
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            Form {
                if !viewModel.isLoadingPrincipals && !isPageLoading {
                    pageContent
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .overlay {
                if viewModel.isLoadingPrincipals || isPageLoading {
                    TabInitializingPlaceholder(
                        icon: pageLoadingIcon,
                        title: pageLoadingTitle,
                        subtitle: "Fetching data from server\u{2026}"
                    )
                }
            }
            .id(selectedPage)
            .frame(minWidth: 500, minHeight: 400)
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
            await viewModel.loadPrincipals(session: session)
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

    // MARK: - Principal Picker

    private var principalPicker: some View {
        VStack(spacing: SpacingTokens.xs) {
            Text("Principal")
                .font(TypographyTokens.formLabel)
                .foregroundStyle(ColorTokens.Text.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Picker("", selection: $viewModel.selectedPrincipalName) {
                if viewModel.selectedPrincipalName.isEmpty {
                    Text("Select a principal\u{2026}").tag("")
                }
                ForEach(viewModel.principals) { principal in
                    Text("\(principal.name) (\(principal.displayType))")
                        .tag(principal.name)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .onChange(of: viewModel.selectedPrincipalName) { _, _ in
                Task { await viewModel.onPrincipalChanged(session: session) }
            }
        }
        .padding(SpacingTokens.sm)
    }

    // MARK: - Page List

    private var pageList: some View {
        List(viewModel.pages, id: \.self, selection: $selectedPage) { page in
            Label(page.title, systemImage: page.icon)
                .tag(page)
        }
        .listStyle(.sidebar)
    }

    // MARK: - Title

    private var navigationTitleText: String {
        guard let page = selectedPage else { return principalDisplayName }
        if page == .securables && viewModel.selectedPrincipalName.isEmpty {
            return "Permission Manager"
        }
        return page.title
    }

    private var navigationSubtitleText: String {
        guard selectedPage != nil else { return "" }
        return viewModel.selectedPrincipalName.isEmpty ? "" : principalDisplayName
    }

    // MARK: - Loading

    private var isPageLoading: Bool {
        switch selectedPage {
        case .securables: viewModel.isLoadingSecurables
        case .effectivePermissions: viewModel.isLoadingEffective
        case nil: false
        }
    }

    private var pageLoadingIcon: String {
        if viewModel.isLoadingPrincipals { return "person.2" }
        switch selectedPage {
        case .securables: return "lock.shield"
        case .effectivePermissions: return "checklist"
        case nil: return "lock.shield"
        }
    }

    private var pageLoadingTitle: String {
        if viewModel.isLoadingPrincipals { return "Loading Principals" }
        switch selectedPage {
        case .securables: return "Loading Securables"
        case .effectivePermissions: return "Loading Effective Permissions"
        case nil: return "Loading"
        }
    }

    // MARK: - Page Content

    @ViewBuilder
    private var pageContent: some View {
        switch selectedPage {
        case .securables:
            PermissionManagerSecurablesPage(viewModel: viewModel, session: session)
        case .effectivePermissions:
            PermissionManagerEffectivePage(viewModel: viewModel)
        case nil:
            EmptyView()
        }
    }
}
