import SwiftUI

/// A tab's special button in the toolbar (round 37.5, MA1; 37.3's PA1): its symbol in the accent
/// colour and its word in grey; running, Stop with a pulsing red dot (ST1). With a menu, it opens it.
struct TabToolbarSpecialButton: View {
    let item: TabToolbarItem

    var body: some View {
        if item.menu.isEmpty {
            Button(action: item.action) { label }
                .buttonStyle(.plain)
                .disabled(item.isDisabled)
                .help(shownTitle)
                .accessibilityLabel(shownTitle)
        } else {
            Menu {
                TabToolbarMenuItems(items: item.menu)
            } label: { label }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .disabled(item.isDisabled)
                .help(item.title)
        }
    }

    private var shownTitle: String { item.isRunning ? (item.runningTitle ?? "Stop") : item.title }

    private var label: some View {
        HStack(spacing: SpacingTokens.xxs2) {
            if item.isRunning {
                PulsingStatusDot(tint: ColorTokens.Status.error, isPulsing: true)
            } else {
                Image(systemName: item.symbol)
                    .foregroundStyle(item.isDisabled ? ColorTokens.Text.tertiary : ColorTokens.accent)
            }
            Text(shownTitle)
                .foregroundStyle(item.isDisabled ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
        }
        .font(TypographyTokens.standard.weight(.medium))
        .lineLimit(1)
        .padding(.horizontal, SpacingTokens.sm)
        .frame(height: LayoutTokens.Toolbar.glyph)
        .padding(.vertical, LayoutTokens.Toolbar.capsuleVerticalPadding)
        .contentShape(.capsule)
    }
}

/// A tab's other buttons in one capsule, groups split by short hairlines (round 37.5, GR1).
struct TabToolbarGroupCapsule: View {
    let groups: [[TabToolbarItem]]

    var body: some View {
        HStack(spacing: SpacingTokens.none) {
            ForEach(Array(groups.enumerated()), id: \.offset) { position, items in
                if position > 0 { TabToolbarHairline() }
                ForEach(items) { TabToolbarGlyphButton(item: $0) }
            }
        }
        .padding(.horizontal, LayoutTokens.Toolbar.capsuleHorizontalPadding)
        .padding(.vertical, LayoutTokens.Toolbar.capsuleVerticalPadding)
    }
}

/// One symbol in the group: a button, a toggle, a menu, or a spinner while busy.
struct TabToolbarGlyphButton: View {
    let item: TabToolbarItem

    var body: some View {
        Group {
            if item.isBusy {
                ProgressView().controlSize(.small)
            } else if item.menu.isEmpty {
                Button(action: item.action) { glyph }
                    .buttonStyle(.plain)
            } else {
                Menu { TabToolbarMenuItems(items: item.menu) } label: { glyph }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .menuIndicator(.hidden)
                    .fixedSize()
            }
        }
        .frame(width: LayoutTokens.Toolbar.glyph, height: LayoutTokens.Toolbar.glyph)
        .disabled(item.isDisabled)
        .help(item.title)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(item.isOn ? .isSelected : [])
    }

    private var glyph: some View {
        Image(systemName: item.symbol)
            .font(TypographyTokens.standard)
            .foregroundStyle(item.isDisabled ? ColorTokens.Text.tertiary : (item.isOn ? ColorTokens.accent : ColorTokens.Text.primary))
            .frame(width: LayoutTokens.Toolbar.glyph, height: LayoutTokens.Toolbar.glyph)
            .contentShape(.rect)
    }
}

/// The items of a menu button; a title starting with "—" is a divider.
struct TabToolbarMenuItems: View {
    let items: [TabToolbarItem]

    var body: some View {
        ForEach(items) { item in
            if item.title == "—" {
                Divider()
            } else {
                Button(item.title, systemImage: item.symbol, action: item.action)
                    .disabled(item.isDisabled)
            }
        }
    }
}
