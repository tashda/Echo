#if os(macOS)
import SwiftUI

struct JsonViewerSheet: View {
    @Bindable var viewModel: JsonViewerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: JsonViewerTab = .tree

    enum JsonViewerTab: Hashable {
        case tree
        case raw
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            switch selectedTab {
            case .tree:
                treeContent
            case .raw:
                rawContent
            }
        }
        .frame(minWidth: 560, idealWidth: 720, minHeight: 440, idealHeight: 600)
    }

    private var toolbar: some View {
        HStack(spacing: SpacingTokens.sm) {
            Text(viewModel.columnName)
                .font(TypographyTokens.prominent.weight(.semibold))

            Picker("", selection: $selectedTab) {
                Text("Tree").tag(JsonViewerTab.tree)
                Text("Raw").tag(JsonViewerTab.raw)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 120)
            .labelsHidden()

            Spacer()

            if selectedTab == .tree {
                HStack(spacing: SpacingTokens.xs2) {
                    Button("Expand All") { viewModel.expandAll() }
                        .controlSize(.small)
                    Button("Collapse All") { viewModel.collapseAll() }
                        .controlSize(.small)
                }

                searchField
            }

            Button {
                PlatformClipboard.copy(viewModel.rawJSON)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .controlSize(.small)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.sm)
    }

    private var searchField: some View {
        HStack(spacing: SpacingTokens.xxs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(ColorTokens.Text.secondary)
                .font(TypographyTokens.detail)
            TextField("Search", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(TypographyTokens.detail)
        }
        .padding(.horizontal, SpacingTokens.xs)
        .padding(.vertical, SpacingTokens.xxs)
        .background(ColorTokens.Background.secondary, in: RoundedRectangle(cornerRadius: 6))
        .frame(maxWidth: 180)
    }

    private var treeContent: some View {
        GeometryReader { geo in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.flatRows) { row in
                        JsonViewerNodeRow(
                            node: row.node,
                            parentPath: row.parentPath,
                            depth: row.depth,
                            isExpanded: viewModel.isExpanded(row.node.id),
                            onToggle: { viewModel.toggle(row.node.id) }
                        )
                    }
                }
                .padding(SpacingTokens.sm)
                .frame(minWidth: geo.size.width, alignment: .leading)
            }
        }
        .background(ColorTokens.Background.primary)
    }

    private var rawContent: some View {
        ScrollView([.vertical, .horizontal]) {
            Text(viewModel.formattedJSON ?? viewModel.rawJSON)
                .font(TypographyTokens.monospaced)
                .textSelection(.enabled)
                .padding(SpacingTokens.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(ColorTokens.Background.primary)
        .onAppear { viewModel.prepareFormattedJSON() }
    }
}
#endif
