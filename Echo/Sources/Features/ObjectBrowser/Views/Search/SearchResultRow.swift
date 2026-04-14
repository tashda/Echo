import SwiftUI
import EchoSense

struct SearchResultRow: View {
    let result: SearchSidebarResult
    let query: String
    var serverName: String?
    var databaseName: String?
    let onSelect: () -> Void
    let fetchDefinition: (() async throws -> String)?
    var onOpenDefinitionInEditor: ((String) -> Void)?

    @State internal var isHovered = false
    @State internal var isInfoPresented = false
    @State internal var infoState: InfoState = .idle

    var body: some View {
        rowContent
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
#if os(macOS)
            .onHover { isHovered = $0 }
#endif
            .onChange(of: isInfoPresented) { _, newValue in
                if !newValue { infoState = .idle }
            }
    }

    // MARK: - Layout

    /// Two-line row: name + badge on line 1, path on line 2.
    private var rowContent: some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: result.category.systemImage)
                .font(TypographyTokens.detail.weight(.medium))
                .foregroundStyle(ColorTokens.Text.tertiary)
                .frame(width: 16, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                // Line 1: Name + trailing badge
                HStack(spacing: SpacingTokens.xs) {
                    Text(result.title)
                        .font(TypographyTokens.standard)
                        .foregroundStyle(ColorTokens.Text.primary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    if let metadata = result.metadata, !metadata.isEmpty {
                        let tint: Color = result.category == .columns
                            ? ColorTokens.accent
                            : ColorTokens.Text.secondary
                        Text(metadata)
                            .font(TypographyTokens.label.weight(.medium))
                            .foregroundStyle(tint)
                            .padding(.horizontal, SpacingTokens.xxs2)
                            .padding(.vertical, 1)
                            .background(tint.opacity(0.1), in: Capsule())
                            .lineLimit(1)
                            .layoutPriority(-1)
                    }

                    if let fetchDefinition {
                        infoButton(fetch: fetchDefinition)
                    }
                }

                // Line 2: Path context — "schema.table · server › database"
                if let detail = detailLine {
                    Text(detail)
                        .font(TypographyTokens.label)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .padding(.horizontal, SpacingTokens.xs)
        .padding(.vertical, SpacingTokens.xxs2)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovered ? ColorTokens.Text.primary.opacity(0.06) : .clear)
        )
    }

    // MARK: - Detail Line

    /// Combines subtitle (schema.table) and provenance (server › db) into one line.
    private var detailLine: String? {
        var parts: [String] = []

        if let subtitle = result.subtitle, !subtitle.isEmpty {
            parts.append(subtitle)
        }

        if let provenance = provenanceText {
            parts.append(provenance)
        }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var provenanceText: String? {
        switch (serverName, databaseName) {
        case (.some(let server), .some(let db)) where !server.isEmpty && !db.isEmpty:
            return "\(server) › \(db)"
        case (.some(let server), _) where !server.isEmpty:
            return server
        case (_, .some(let db)) where !db.isEmpty:
            return db
        default:
            return nil
        }
    }

    // MARK: - State

    internal var shouldHighlightSnippet: Bool {
        switch result.category {
        case .views, .materializedViews, .functions, .procedures, .triggers, .queryTabs:
            return true
        default:
            return false
        }
    }

    internal enum InfoState: Equatable {
        case idle
        case loading
        case loaded(String)
        case failed(String)
    }
}
