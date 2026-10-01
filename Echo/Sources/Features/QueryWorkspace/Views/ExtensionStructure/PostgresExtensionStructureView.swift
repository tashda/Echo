import SwiftUI
import AppKit

struct PostgresExtensionStructureView: View {
    @Bindable var tab: WorkspaceTab
    var viewModel: PostgresExtensionStructureViewModel

    @Environment(EnvironmentState.self) private var environmentState
    
    var body: some View {
        // One theme (round 37.1): the shared header names it, with its version after the server;
        // Update, Homepage, Documentation and Refresh are in the window toolbar (round 37.5).
        VStack(spacing: 0) {
            if viewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading extension details\u{2026}")
                    Spacer()
                }
            } else if let error = viewModel.errorMessage {
                VStack(spacing: SpacingTokens.md) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(TypographyTokens.hero)
                        .foregroundStyle(ColorTokens.Status.warning)
                    Text(error)
                        .font(TypographyTokens.standard)
                    Button("Retry") {
                        Task { await viewModel.reload() }
                    }
                    Spacer()
                }
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.Background.primary)
        .toolTabHeaderDetail(viewModel.currentVersion.map { "v\($0)" })
        .tabToolbar(special: updateItem, groups: [linkItems + [.refresh(isBusy: viewModel.isLoading) { [viewModel] in Task { await viewModel.reload() } }]])
        .task {
            if viewModel.objects.isEmpty {
                await viewModel.reload()
            }
        }
    }
    
    /// Update to the newest version, when there is one.
    private var updateItem: TabToolbarItem? {
        guard viewModel.canUpdate else { return nil }
        return TabToolbarItem(id: "update", title: "Update to v\(viewModel.latestVersion ?? "?")", symbol: "arrow.up.circle",
                              isDisabled: viewModel.isUpdating, isRunning: viewModel.isUpdating, runningTitle: "Updating") { [viewModel] in
            Task { await viewModel.update() }
        }
    }

    /// The extension's homepage and documentation, when it has them.
    private var linkItems: [TabToolbarItem] {
        var items: [TabToolbarItem] = []
        if let home = viewModel.homepageURL, let url = URL(string: home) {
            items.append(TabToolbarItem(id: "homepage", title: "Visit Homepage", symbol: "safari") { NSWorkspace.shared.open(url) })
        }
        if let docs = viewModel.documentationURL, let url = URL(string: docs) {
            items.append(TabToolbarItem(id: "documentation", title: "View Documentation", symbol: "doc.text") { NSWorkspace.shared.open(url) })
        }
        return items
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaneHeader("Owned Objects", count: viewModel.objects.count)
            if let description = viewModel.description {
                Text(description)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(2)
                    .padding(.horizontal, SpacingTokens.sm)
                    .padding(.bottom, SpacingTokens.xs)
            }
            Divider()
            
            if viewModel.objects.isEmpty {
                VStack {
                    Spacer()
                    Text("No objects owned by this extension.")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(viewModel.objects) { object in
                        HStack(spacing: SpacingTokens.sm) {
                            Image(systemName: iconForType(object.type))
                                .foregroundStyle(ColorTokens.Text.secondary)
                                .frame(width: 16)
                            
                            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                                Text(object.name)
                                    .font(TypographyTokens.standard)
                                Text(object.schema)
                                    .font(TypographyTokens.caption2)
                                    .foregroundStyle(ColorTokens.Text.tertiary)
                            }
                            
                            Spacer()
                            
                            Text(object.type)
                                .font(TypographyTokens.label)
                                .foregroundStyle(ColorTokens.Text.quaternary)
                        }
                        .padding(.vertical, SpacingTokens.xxs)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
    
    private func iconForType(_ type: String) -> String {
        switch type.uppercased() {
        case "TABLE": return "tablecells"
        case "VIEW": return "eye"
        case "INDEX": return "shippingbox"
        case "FUNCTION": return "function"
        case "TYPE": return "square.stack.3d.up"
        case "SEQUENCE": return "list.number"
        default: return "cube"
        }
    }
}
