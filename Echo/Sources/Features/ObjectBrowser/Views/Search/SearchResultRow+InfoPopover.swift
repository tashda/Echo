import SwiftUI
import EchoSense

extension SearchResultRow {
    func infoButton(fetch: @escaping () async throws -> String) -> some View {
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
                .font(TypographyTokens.caption2.weight(.semibold))
                .foregroundStyle(isInfoPresented ? Color.accentColor : Color.secondary)
                .padding(SpacingTokens.xxs2)
                .background(
                    Circle()
                        .fill(Color.primary.opacity(isInfoPresented ? 0.12 : 0.04))
                )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isInfoPresented, arrowEdge: .trailing) {
            infoPopover(fetch: fetch)
                .frame(minWidth: 420, idealWidth: 480, maxWidth: 520)
                .padding(SpacingTokens.md2)
        }
    }

    func infoPopover(fetch: @escaping () async throws -> String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(result.title)
                .font(.headline)

            switch infoState {
            case .idle, .loading:
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Loading definition...")
                        .font(TypographyTokens.caption2)
                        .foregroundStyle(.secondary)
                }
                .task {
                    await loadDefinition(fetch: fetch)
                }
            case .failed(let message):
                Text(message)
                    .font(TypographyTokens.caption2)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            case .loaded(let definition):
                ScrollView {
                    Text(definition)
                        .font(TypographyTokens.detail.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 400)
            }
        }
    }

    func loadDefinition(fetch: @escaping () async throws -> String) async {
        guard case .loading = infoState else { return }
        do {
            let definition = try await fetch()
            infoState = .loaded(definition)
        } catch {
            infoState = .failed(error.localizedDescription)
        }
    }

    func snippetText(for snippet: String) -> Text {
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
            matchAttributed.font = .system(size: 11).weight(.semibold)
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

    func truncatedSnippet(_ snippet: String) -> String {
        guard shouldHighlightSnippet else { return snippet }
        let limit = 140
        guard snippet.count > limit else { return snippet }
        let endIndex = snippet.index(snippet.startIndex, offsetBy: limit, limitedBy: snippet.endIndex) ?? snippet.endIndex
        var truncated = String(snippet[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        if truncated.isEmpty {
            truncated = String(snippet.prefix(limit))
        }
        return truncated.hasSuffix("\u{2026}") ? truncated : truncated + "\u{2026}"
    }
}
