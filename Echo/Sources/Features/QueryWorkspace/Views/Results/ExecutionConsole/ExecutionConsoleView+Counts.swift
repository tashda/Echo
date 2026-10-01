import SwiftUI

/// The top of Messages (round 41.4, MT1): "1 error · 2 warnings · 3 messages", each a filter
/// (click again for all), and a ⋯ menu with Copy All Messages and Clear Messages.
struct MessageCountsBar: View {
    let messages: [QueryExecutionMessage]
    @Binding var filter: MessageFilter
    let onCopyAll: () -> Void
    var onClear: (() -> Void)?

    private func count(_ kind: MessageFilter) -> Int { messages.filter(kind.includes).count }

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            countButton(.errors, singular: "error", plural: "errors", tint: ColorTokens.Status.error)
            countButton(.warnings, singular: "warning", plural: "warnings", tint: ColorTokens.Status.warning)
            countButton(.others, singular: "message", plural: "messages", tint: ColorTokens.Text.secondary)
            Spacer(minLength: SpacingTokens.xs)
            Menu {
                Button("Copy All Messages", systemImage: "doc.on.doc", action: onCopyAll)
                if let onClear {
                    Button("Clear Messages", systemImage: "trash", role: .destructive, action: onClear)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("More")
            .accessibilityLabel("More")
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.top, SpacingTokens.sm)
        .padding(.bottom, SpacingTokens.xxs)
    }

    @ViewBuilder
    private func countButton(_ kind: MessageFilter, singular: String, plural: String, tint: Color) -> some View {
        let count = count(kind)
        if count > 0 {
            let isActive = filter == kind
            Button {
                filter = isActive ? .all : kind
            } label: {
                Text("\(count.formatted()) \(count == 1 ? singular : plural)")
                    .font(TypographyTokens.detail.weight(kind == .errors ? .semibold : .regular))
                    .foregroundStyle(tint)
                    .padding(.horizontal, SpacingTokens.xxs2)
                    .padding(.vertical, SpacingTokens.micro)
                    .background(isActive ? ColorTokens.Sidebar.selectedFill : Color.clear, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .help(isActive ? "Show all messages" : "Show only these")
        }
    }
}
