import SwiftUI

struct SequenceEditorView: View {
    @Bindable var viewModel: SequenceEditorViewModel
    let session: ConnectionSession
    let onDismiss: () -> Void

    @State private var selectedPage: SequenceEditorPage? = .general

    private var displayName: String {
        viewModel.sequenceName.isEmpty ? "New Sequence" : viewModel.sequenceName
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
                if selectedPage == .sql {
                    sqlDetail
                } else {
                    formDetail
                }
            }
            .frame(minWidth: 440, minHeight: 400)
            .navigationTitle(navigationTitleText)
            .navigationSubtitle(navigationSubtitleText)
            .toolbarTitleDisplayMode(.automatic)
            .toolbar { toolbarContent }
        }
        .background(PocketSeparatorHider())
        .background(UnsavedChangesGuard(
            hasChanges: viewModel.hasChanges,
            onDiscard: onDismiss
        ))
        .task {
            viewModel.errorMessage = nil
            await viewModel.load(session: session)
        }
        .overlay(alignment: .bottom) { errorBanner }
        .animation(.easeInOut(duration: 0.2), value: viewModel.errorMessage)
    }

    // MARK: - Form Detail

    private var formDetail: some View {
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
                    icon: "number",
                    title: "Loading Sequence",
                    subtitle: "Fetching data from server\u{2026}"
                )
            }
        }
        .id(selectedPage)
    }

    // MARK: - SQL Detail

    private var sqlDetail: some View {
        SequenceEditorSQLPage(viewModel: viewModel)
    }

    // MARK: - Page Content

    @ViewBuilder
    private var pageContent: some View {
        switch selectedPage {
        case .general:
            SequenceEditorGeneralPage(viewModel: viewModel)
        case .values:
            SequenceEditorValuesPage(viewModel: viewModel)
        case .sql, nil:
            EmptyView()
        }
    }

    // MARK: - Title

    private var navigationTitleText: String {
        guard let page = selectedPage else { return displayName }
        if page == .general { return displayName }
        return page.title
    }

    private var navigationSubtitleText: String {
        guard let page = selectedPage else { return "" }
        if page == .general { return "" }
        return displayName
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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

    // MARK: - Error Banner

    @ViewBuilder
    private var errorBanner: some View {
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
}
