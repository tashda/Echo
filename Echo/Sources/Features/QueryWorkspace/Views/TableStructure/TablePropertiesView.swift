import SwiftUI

struct TablePropertiesView: View {
    @Bindable var viewModel: TablePropertiesViewModel
    let session: ConnectionSession
    let onDismiss: () -> Void

    @State private var selectedPage: TablePropertiesPage? = .general

    var body: some View {
        NavigationSplitView {
            List(viewModel.pages, id: \.self, selection: $selectedPage) { page in
                Label(page.title, systemImage: page.icon)
                    .tag(page)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
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
                        icon: "tablecells",
                        title: "Loading Properties",
                        subtitle: "Fetching table configuration\u{2026}"
                    )
                }
            }
            .id(selectedPage)
            .frame(minWidth: 400, minHeight: 360)
            .navigationTitle(navigationTitleText)
            .navigationSubtitle(navigationSubtitleText)
            .toolbarTitleDisplayMode(.automatic)
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
        guard let page = selectedPage else { return viewModel.tableName }
        if page == .general { return "\(viewModel.schemaName).\(viewModel.tableName)" }
        return page.title
    }

    private var navigationSubtitleText: String {
        guard let page = selectedPage else { return "" }
        if page == .general { return "" }
        return "\(viewModel.schemaName).\(viewModel.tableName)"
    }

    // MARK: - Page Content

    @ViewBuilder
    private var pageContent: some View {
        switch selectedPage {
        case .general:
            generalPage
        case .storage:
            storagePage
        case .changeTracking:
            changeTrackingPage
        case .temporal:
            temporalPage
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
