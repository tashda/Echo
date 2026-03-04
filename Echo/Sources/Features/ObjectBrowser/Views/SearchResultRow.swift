import SwiftUI
import EchoSense

struct SearchResultRow: View {
    let result: SearchSidebarResult
    let query: String
    let onSelect: () -> Void
    let fetchDefinition: (() async throws -> String)?

    @State private var isHovered = false
    @State private var isInfoPresented = false
    @State private var infoState: InfoState = .idle

    var body: some View {
        rowContent
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onTapGesture(perform: onSelect)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
#if os(macOS)
            .onHover { hovering in
                isHovered = hovering
            }
#endif
            .onChange(of: isInfoPresented) { _, newValue in
                if !newValue {
                    infoState = .idle
                }
            }
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: result.category.systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if let subtitle = result.subtitle, !subtitle.isEmpty {
                            if shouldShowBadge {
                                Text(subtitle)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.primary.opacity(0.08), in: Capsule())
                            } else {
                                Text(subtitle)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        if let metadata = result.metadata,
                           !metadata.isEmpty {
                            let tint: Color = (result.category == .columns) ? .accentColor : .secondary
                            Text(metadata)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(tint)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(tint.opacity(0.08), in: Capsule())
                        }

                        if let fetchDefinition {
                            infoButton(fetch: fetchDefinition)
                        }
                    }
                }

                if let snippet = result.snippet, !snippet.isEmpty {
                    snippetText(for: truncatedSnippet(snippet))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(cardBorder)
        .shadow(color: isHovered ? Color.black.opacity(0.12) : .clear, radius: isHovered ? 14 : 0, y: isHovered ? 8 : 0)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.16), value: isHovered)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }

    private func snippetText(for snippet: String) -> Text {
        guard shouldHighlightSnippet, !query.isEmpty else {
            return Text(snippet)
        }

        var attributed = AttributedString()
        var currentIndex = snippet.startIndex
        let endIndex = snippet.endIndex
        var searchRange = currentIndex..<endIndex

        while let matchRange = snippet.range(of: query, options: [.caseInsensitive], range: searchRange) {
            if matchRange.lowerBound > currentIndex {
                let prefix = String(snippet[currentIndex..<matchRange.lowerBound])
                if !prefix.isEmpty {
                    attributed.append(AttributedString(prefix))
                }
            }

            let matchText = String(snippet[matchRange])
            var matchAttributed = AttributedString(matchText)
            matchAttributed.font = .system(size: 11, weight: .semibold)
            attributed.append(matchAttributed)

            currentIndex = matchRange.upperBound
            searchRange = currentIndex..<endIndex
        }

        if currentIndex < endIndex {
            let suffix = String(snippet[currentIndex..<endIndex])
            if !suffix.isEmpty {
                attributed.append(AttributedString(suffix))
            }
        }

        if attributed.characters.isEmpty {
            return Text(snippet)
        }

        return Text(attributed)
    }

    private func truncatedSnippet(_ snippet: String) -> String {
        guard shouldHighlightSnippet else { return snippet }
        let limit = 140
        guard snippet.count > limit else { return snippet }
        let endIndex = snippet.index(snippet.startIndex, offsetBy: limit, limitedBy: snippet.endIndex) ?? snippet.endIndex
        var truncated = String(snippet[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        if truncated.isEmpty {
            truncated = String(snippet.prefix(limit))
        }
        return truncated.hasSuffix("…") ? truncated : truncated + "…"
    }

    private func infoButton(fetch: @escaping () async throws -> String) -> some View {
        Button {
            if isInfoPresented {
                isInfoPresented = false
                infoState = .idle
            } else {
                infoState = .loading
                isInfoPresented = true
            }
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isInfoPresented ? Color.accentColor : Color.secondary)
                .padding(6)
                .background(
                    Circle()
                        .fill(Color.primary.opacity(isInfoPresented ? 0.12 : 0.04))
                )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isInfoPresented, arrowEdge: .trailing) {
            infoPopover(fetch: fetch)
                .frame(minWidth: 420, idealWidth: 480, maxWidth: 520)
                .padding(20)
        }
    }

    private func infoPopover(fetch: @escaping () async throws -> String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(result.title)
                .font(.headline)

            switch infoState {
            case .idle, .loading:
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Loading definition…")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .task {
                    await loadDefinition(fetch: fetch)
                }
            case .failed(let message):
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            case .loaded(let definition):
                ScrollView {
                    Text(definition)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 400)
            }

        }
    }

    private func loadDefinition(fetch: @escaping () async throws -> String) async {
        guard case .loading = infoState else { return }
        do {
            let definition = try await fetch()
            infoState = .loaded(definition)
        } catch {
            infoState = .failed(error.localizedDescription)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.primary.opacity(isHovered ? 0.08 : 0.04))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(isHovered ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.05), lineWidth: 1)
    }

    private var shouldHighlightSnippet: Bool {
        switch result.category {
        case .views, .materializedViews, .functions, .procedures, .triggers, .queryTabs:
            return true
        default:
            return false
        }
    }

    private var shouldShowBadge: Bool {
        switch result.category {
        case .tables, .views, .materializedViews, .columns, .indexes, .foreignKeys:
            return true
        default:
            return false
        }
    }

    private enum InfoState: Equatable {
        case idle
        case loading
        case loaded(String)
        case failed(String)
    }
}
