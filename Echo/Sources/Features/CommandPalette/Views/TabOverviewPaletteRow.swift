import SwiftUI

/// A tab in the palette's tab overview (round 35.1, TO6): its symbol, title and database, and on
/// the right its state as a dot and a word, read live from the tab.
struct TabOverviewPaletteRow: View {
    let tab: WorkspaceTab
    let entry: TabOverviewEntry
    let isSelected: Bool
    let isActive: Bool

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: tab.kind.icon)
                .font(TypographyTokens.standard)
                .foregroundStyle(isSelected ? ColorTokens.accent : ColorTokens.Text.secondary)
                .frame(width: SpacingTokens.md)
            Text(entry.title)
                .font(TypographyTokens.standard.weight(isActive ? .semibold : .regular))
                .foregroundStyle(ColorTokens.Text.primary)
                .lineLimit(1)
                .layoutPriority(1)
            if !entry.detail.isEmpty {
                Text(entry.detail)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            if tab.isPinned {
                Image(systemName: "pin.fill")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .accessibilityLabel("Pinned")
            }
            Spacer(minLength: SpacingTokens.xs)
            if let status = tab.overviewStatus {
                Circle()
                    .fill(Self.tint(for: status))
                    .frame(width: SpacingTokens.xxs2, height: SpacingTokens.xxs2)
                Text(status.text)
                    .font(TypographyTokens.detail.monospacedDigit())
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
        .padding(.horizontal, SpacingTokens.xs)
        .frame(height: LayoutTokens.FloatingSurface.rowHeight)
        .background(
            isSelected ? ColorTokens.Sidebar.selectedFill : .clear,
            in: RoundedRectangle(cornerRadius: LayoutTokens.FloatingSurface.rowCornerRadius, style: .continuous)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    static func tint(for status: TabOverviewStatus) -> Color {
        switch status {
        case .notRun, .cancelled: ColorTokens.Text.tertiary
        case .running: ColorTokens.Status.warning
        case .failed: ColorTokens.Status.error
        case .finished: ColorTokens.Status.success
        }
    }
}
