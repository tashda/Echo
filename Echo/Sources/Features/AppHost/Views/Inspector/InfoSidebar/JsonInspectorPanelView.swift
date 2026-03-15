#if os(macOS)
import SwiftUI

struct JsonInspectorPanelView: View {
    let content: JsonInspectorContent
    @State private var viewModel: JsonViewerViewModel?
    @State private var isLoading = false
    @State private var selectedTab: JsonInspectorTab = .raw
    @State private var buildTask: Task<Void, Never>?
    @State private var showFullRaw = false

    enum JsonInspectorTab: String, Hashable {
        case raw
        case tree
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            header
            tabControls

            if isLoading {
                loadingContent
            } else {
                switch selectedTab {
                case .raw:
                    rawContent
                case .tree:
                    treeContent
                }
            }
        }
        .padding(.top, SpacingTokens.xxs)
        .padding(.bottom, SpacingTokens.xxs)
        .onAppear { buildViewModelAsync() }
        .onChange(of: content) { _, _ in buildViewModelAsync() }
        .onDisappear { buildTask?.cancel() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                Text(content.title)
                    .font(TypographyTokens.prominent.weight(.semibold))
                if let subtitle = content.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
            Spacer()
            Button {
                PlatformClipboard.copy(viewModel?.formattedJSON ?? content.rawJSON)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .help("Copy JSON")
        }
    }

    // MARK: - Tab Controls

    private var tabControls: some View {
        HStack(spacing: SpacingTokens.xs) {
            Picker("", selection: $selectedTab) {
                Text("Raw").tag(JsonInspectorTab.raw)
                Text("Tree").tag(JsonInspectorTab.tree)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 120)
            .labelsHidden()
            .controlSize(.small)

            if selectedTab == .tree, let vm = viewModel, !isLoading {
                Spacer()
                Button("Expand") { vm.expandAll() }
                    .buttonStyle(.borderless)
                    .controlSize(.mini)
                Button("Collapse") { vm.collapseAll() }
                    .buttonStyle(.borderless)
                    .controlSize(.mini)
            }
        }
    }

    // MARK: - Loading

    private var loadingContent: some View {
        VStack(spacing: SpacingTokens.sm) {
            ProgressView()
                .controlSize(.small)
            Text("Parsing JSON\u{2026}")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, SpacingTokens.lg)
    }

    // MARK: - Raw Content

    private static let rawDisplayLimit = 8_000

    @ViewBuilder
    private var rawContent: some View {
        let formatted = viewModel?.formattedJSON ?? content.rawJSON
        let isTruncated = formatted.count > Self.rawDisplayLimit
        let displayText = isTruncated && !showFullRaw
            ? String(formatted.prefix(Self.rawDisplayLimit)) + "\n\u{2026}"
            : formatted
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                Text(displayText)
                    .font(TypographyTokens.detail.monospaced())
                    .textSelection(.enabled)
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isTruncated && !showFullRaw {
                    Button("Show all (\(ByteCountFormatter.string(fromByteCount: Int64(formatted.utf8.count), countStyle: .file)))") {
                        showFullRaw = true
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
            .padding(SpacingTokens.xs)
        }
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(ColorTokens.Background.secondary)
        )
        .onAppear { viewModel?.prepareFormattedJSON() }
        .onChange(of: content) { _, _ in showFullRaw = false }
    }

    // MARK: - Tree Content

    @ViewBuilder
    private var treeContent: some View {
        if let vm = viewModel {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(vm.flatRows) { row in
                    JsonViewerNodeRow(
                        node: row.node,
                        parentPath: row.parentPath,
                        depth: row.depth,
                        isExpanded: vm.isExpanded(row.node.id),
                        onToggle: { vm.toggle(row.node.id) }
                    )
                }
            }
        }
    }

    // MARK: - Async ViewModel Construction

    private func buildViewModelAsync() {
        buildTask?.cancel()
        let rawJSON = content.rawJSON
        let title = content.title

        // For small JSON (<4KB), build synchronously to avoid flicker
        if rawJSON.utf8.count < 4_096 {
            let outline = Self.parseOutline(rawJSON: rawJSON)
            let vm = JsonViewerViewModel(rootNode: outline, rawJSON: rawJSON, columnName: title)
            vm.prepareFormattedJSON()
            viewModel = vm
            isLoading = false
            return
        }

        isLoading = true
        viewModel = nil

        buildTask = Task {
            let outline = await Task.detached(priority: .userInitiated) {
                Self.parseOutline(rawJSON: rawJSON)
            }.value

            guard !Task.isCancelled else { return }
            let vm = JsonViewerViewModel(rootNode: outline, rawJSON: rawJSON, columnName: title)
            vm.prepareFormattedJSON()
            viewModel = vm
            isLoading = false
        }
    }

    private nonisolated static func parseOutline(rawJSON: String) -> JsonOutlineNode {
        if let parsed = try? JsonValue.parse(from: rawJSON) {
            return parsed.toOutlineNode()
        }
        return JsonOutlineNode(id: UUID(), key: .root, value: .string(rawJSON), children: [])
    }
}
#endif
