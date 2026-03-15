import SwiftUI
import EchoSense

struct SearchResultRow: View {
    let result: SearchSidebarResult
    let query: String
    let onSelect: () -> Void
    let fetchDefinition: (() async throws -> String)?

    @State internal var isHovered = false
    @State internal var isInfoPresented = false
    @State internal var infoState: InfoState = .idle

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
        HStack(alignment: .top, spacing: SpacingTokens.sm) {
            Image(systemName: result.category.systemImage)
                .font(TypographyTokens.caption2.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.secondary)
                .frame(width: 18)
                .padding(.top, SpacingTokens.xxxs)

            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.sm) {
                    VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                        Text(result.title)
                            .font(TypographyTokens.standard.weight(.semibold))
                            .foregroundStyle(ColorTokens.Text.primary)
                            .lineLimit(1)

                        if let subtitle = result.subtitle, !subtitle.isEmpty {
                            if shouldShowBadge {
                                Text(subtitle)
                                    .font(TypographyTokens.label.weight(.medium))
                                    .foregroundStyle(ColorTokens.Text.secondary)
                                    .padding(.horizontal, SpacingTokens.xs)
                                    .padding(.vertical, SpacingTokens.xxxs)
                                    .background(ColorTokens.Text.primary.opacity(0.08), in: Capsule())
                            } else {
                                Text(subtitle)
                                    .font(TypographyTokens.detail)
                                    .foregroundStyle(ColorTokens.Text.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: SpacingTokens.xs) {
                        if let metadata = result.metadata,
                           !metadata.isEmpty {
                            let tint: Color = (result.category == .columns) ? ColorTokens.accent : ColorTokens.Text.secondary
                            Text(metadata)
                                .font(TypographyTokens.label.weight(.semibold))
                                .foregroundStyle(tint)
                                .padding(.horizontal, SpacingTokens.xs)
                                .padding(.vertical, SpacingTokens.xxxs)
                                .background(tint.opacity(0.08), in: Capsule())
                        }

                        if let fetchDefinition {
                            infoButton(fetch: fetchDefinition)
                        }
                    }
                }

                if let snippet = result.snippet, !snippet.isEmpty {
                    snippetText(for: truncatedSnippet(snippet))
                        .font(TypographyTokens.detail.weight(.medium).monospaced())
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .lineSpacing(SpacingTokens.xxxs)
                }
            }
        }
        .padding(.horizontal, SpacingTokens.sm2)
        .padding(.vertical, SpacingTokens.xs2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(cardBorder)
        .shadow(color: isHovered ? Color.black.opacity(0.12) : .clear, radius: isHovered ? 14 : 0, y: isHovered ? 8 : 0)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.16), value: isHovered)
        .padding(.horizontal, SpacingTokens.xxs2)
        .padding(.vertical, SpacingTokens.xxxs)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(ColorTokens.Text.primary.opacity(isHovered ? 0.08 : 0.04))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(isHovered ? ColorTokens.accent.opacity(0.35) : ColorTokens.Text.primary.opacity(0.05), lineWidth: 1)
    }

    internal var shouldHighlightSnippet: Bool {
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

    internal enum InfoState: Equatable {
        case idle
        case loading
        case loaded(String)
        case failed(String)
    }
}
