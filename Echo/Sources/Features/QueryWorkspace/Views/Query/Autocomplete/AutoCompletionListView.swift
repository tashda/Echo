import SwiftUI
import EchoSense

struct AutoCompletionListView: View {
    let suggestions: [SQLAutoCompletionSuggestion]
    let selectedID: String?
    let onSelect: @Sendable (SQLAutoCompletionSuggestion) -> Void
    let detailResetID: UUID
    let statusMessage: String?

    @Environment(\.colorScheme) private var colorScheme
    @State private var isDetailVisible = false
    @State private var detailWorkItem: DispatchWorkItem?
    @State private var detailUnlocked = false

    private enum Layout {
        static let rowCornerRadius: CGFloat = 5
        static let detailWidth: CGFloat = 240
        static let containerCornerRadius: CGFloat = 8
        static let horizontalPadding: CGFloat = SpacingTokens.xxs2
        static let verticalPadding: CGFloat = SpacingTokens.xxs2
        static let containerSpacing: CGFloat = 0
        static let detailRevealDelay: TimeInterval = 1.0
        static let rowHorizontalPadding: CGFloat = SpacingTokens.xs
        static let rowIconSpacing: CGFloat = SpacingTokens.xxs2
        static let rowIconSize: CGFloat = 14
        static let minListWidth: CGFloat = 220
    }

    private var selectedSuggestion: SQLAutoCompletionSuggestion? {
        guard let selectedID else { return nil }
        return suggestions.first { $0.id == selectedID }
    }

    private var shouldDisplayDetail: Bool {
        guard let suggestion = selectedSuggestion, isDetailVisible else { return false }
        if let path = suggestion.displayObjectPath, !path.isEmpty { return true }
        if suggestion.kind == .column, let type = suggestion.dataType, !type.isEmpty { return true }
        return suggestion.serverDisplayName != nil
    }

    private var listWidth: CGFloat {
#if os(macOS)
        let font = NSFont.systemFont(ofSize: 13)
        let titleWidth = suggestions.map { ($0.title as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
        return max(Layout.minListWidth, Layout.rowHorizontalPadding * 2 + Layout.rowIconSize + Layout.rowIconSpacing + titleWidth)
#else
        return Layout.minListWidth
#endif
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                if let statusMessage {
                    Text(statusMessage)
                        .font(TypographyTokens.detail.weight(.medium))
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .padding(.horizontal, Layout.rowHorizontalPadding)
                }
                listView
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical, Layout.verticalPadding)
            if shouldDisplayDetail, let suggestion = selectedSuggestion {
                Divider()
                AutoCompletionDetailView(suggestion: suggestion).frame(width: Layout.detailWidth, alignment: .leading).transition(.move(edge: .trailing).combined(with: .opacity)).id(suggestion.id)
            }
        }
        .background(backgroundMaterial).overlay(borderOverlay).id(detailResetID)
        .onAppear { scheduleDetailReveal(forceReset: true) }
        .onChange(of: selectedID) { _, _ in scheduleDetailReveal(forceReset: false) }
        .onDisappear { cancelDetailReveal() }
    }

    private var listView: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(suggestions) { suggestion in
                        AutoCompletionRowView(suggestion: suggestion, isSelected: suggestion.id == selectedID) { onSelect(suggestion) }
                            .id(suggestion.id)
                    }
                }
            }
            .frame(minWidth: listWidth, idealWidth: listWidth)
            .onChange(of: selectedID) { _, _ in if let selectedID { proxy.scrollTo(selectedID, anchor: .center) } }
        }
    }

    @ViewBuilder private var backgroundMaterial: some View {
#if os(macOS)
        Color.clear
#else
        RoundedRectangle(cornerRadius: Layout.containerCornerRadius, style: .continuous).fill(Color.white.opacity(colorScheme == .dark ? 0.2 : 0.95))
#endif
    }

    @ViewBuilder private var borderOverlay: some View {
#if !os(macOS)
        RoundedRectangle(cornerRadius: Layout.containerCornerRadius, style: .continuous).stroke(Color.black.opacity(0.1), lineWidth: 1)
#else
        EmptyView()
#endif
    }

    private func scheduleDetailReveal(forceReset: Bool) {
        detailWorkItem?.cancel()
        if forceReset { detailUnlocked = false; isDetailVisible = false }
        else if detailUnlocked { isDetailVisible = selectedSuggestion != nil; return }
        guard !detailUnlocked, selectedSuggestion != nil else { return }
        let workItem = DispatchWorkItem { detailUnlocked = true; withAnimation(.easeOut(duration: 0.2)) { isDetailVisible = true } }
        detailWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Layout.detailRevealDelay, execute: workItem)
    }

    private func cancelDetailReveal() { detailWorkItem?.cancel(); detailWorkItem = nil; isDetailVisible = false; detailUnlocked = false }
}

struct AutoCompletionRowView: View {
    let suggestion: SQLAutoCompletionSuggestion
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.xxs2) {
                Image(systemName: suggestion.kind.iconSystemName).font(TypographyTokens.detail.weight(.medium)).foregroundStyle(isSelected ? activeIconColor : .secondary).frame(width: 14)
#if os(macOS)
                AutoScrollingText(text: suggestion.title, font: .systemFont(ofSize: 13), isActive: isSelected).foregroundStyle(isSelected ? activeTitleColor : .primary)
#else
                AutoScrollingText(text: suggestion.title, font: .system(size: 13), isActive: isSelected).foregroundStyle(isSelected ? activeTitleColor : .primary)
#endif
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, SpacingTokens.xs).padding(.vertical, SpacingTokens.xxs).contentShape(Rectangle())
        }
        .buttonStyle(.plain).background(rowBackground)
    }

    private var activeIconColor: Color {
#if os(macOS)
        return Color(nsColor: .selectedMenuItemTextColor)
#else
        return .white
#endif
    }

    private var activeTitleColor: Color {
#if os(macOS)
        return Color(nsColor: .selectedMenuItemTextColor)
#else
        return .white
#endif
    }

    private var rowBackground: some View {
        guard isSelected else { return AnyView(EmptyView()) }
#if os(macOS)
        return AnyView(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color(nsColor: .controlAccentColor)))
#else
        return AnyView(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(ColorTokens.accent.opacity(colorScheme == .dark ? 0.32 : 0.22)))
#endif
    }
}
