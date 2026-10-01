import SwiftUI

/// A tool tab's other actions together in one 28pt glass capsule (round 37.3, SA2).
struct ToolTabActionGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: SpacingTokens.sm) {
            content()
        }
        .font(TypographyTokens.standard)
        .foregroundStyle(ColorTokens.Text.primary)
        .padding(.horizontal, SpacingTokens.sm)
        .frame(height: LayoutTokens.ToolTab.controlHeight)
        .glassEffect(.regular, in: .capsule)
    }
}

/// One symbol in a `ToolTabActionGroup`; its title is the tooltip and the accessibility label.
struct ToolTabActionButton: View {
    let title: String
    let systemImage: String
    var isDisabled = false
    /// A toggle that is on (Watch Live Data) shows its symbol in the accent colour.
    var isOn = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(minWidth: SpacingTokens.md, minHeight: LayoutTokens.ToolTab.controlHeight)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isDisabled ? ColorTokens.Text.tertiary : (isOn ? ColorTokens.accent : ColorTokens.Text.primary))
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .disabled(isDisabled)
        .help(title)
        .accessibilityLabel(title)
    }
}

/// Refresh in a `ToolTabActionGroup`: a spinner in its place while the tab reloads.
struct ToolTabRefreshButton: View {
    let isRefreshing: Bool
    let action: () -> Void

    var body: some View {
        if isRefreshing {
            ProgressView()
                .controlSize(.mini)
                .frame(minWidth: SpacingTokens.md, minHeight: LayoutTokens.ToolTab.controlHeight)
                .help("Refreshing")
                .accessibilityLabel("Refreshing")
        } else {
            ToolTabActionButton(title: "Refresh", systemImage: "arrow.clockwise", action: action)
        }
    }
}

/// A symbol in a `ToolTabActionGroup` that opens a menu (Export as PNG, PDF, …).
struct ToolTabActionMenu<Items: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let items: () -> Items

    var body: some View {
        Menu {
            items()
        } label: {
            Image(systemName: systemImage)
                .frame(minWidth: SpacingTokens.md, minHeight: LayoutTokens.ToolTab.controlHeight)
                .contentShape(.rect)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(title)
        .accessibilityLabel(title)
    }
}
