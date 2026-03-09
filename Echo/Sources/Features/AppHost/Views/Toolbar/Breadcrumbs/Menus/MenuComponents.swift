import SwiftUI
import Combine

// MARK: - Shared Menu Components

struct MenuItemView: View {
    let title: String
    let icon: String?
    let iconColor: Color?
    let action: () -> Void
    let isDestructive: Bool

    @State private var isHovered = false

    init(
        title: String,
        icon: String? = nil,
        iconColor: Color? = nil,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.isDestructive = isDestructive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(TypographyTokens.standard.weight(.medium))
                        .foregroundStyle(iconColor ?? .primary)
                        .frame(width: 16)
                }

                Text(title)
                    .font(TypographyTokens.standard.weight(.regular))
                    .foregroundStyle(isDestructive ? .red : .primary)

                Spacer()
            }
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.vertical, SpacingTokens.xxs2)
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct MenuSectionView<Content: View>: View {
    let title: String?
    let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title = title {
                HStack {
                    Text(title.uppercased())
                        .font(TypographyTokens.label.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, SpacingTokens.sm)
                .padding(.vertical, SpacingTokens.xs)
                .padding(.bottom, SpacingTokens.xxxs)
            }

            VStack(alignment: .leading, spacing: 2) {
                content
            }
        }
    }
}

struct MenuSeparator: View {
    var body: some View {
        Divider()
            .padding(.vertical, SpacingTokens.xxs)
            .padding(.horizontal, SpacingTokens.xs)
    }
}

// MARK: - Search Component

struct MenuSearchField: View {
    @Binding var text: String
    let placeholder: String

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(TypographyTokens.detail.weight(.medium))
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(TypographyTokens.caption2)
                .focused($isFocused)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, SpacingTokens.xs)
        .padding(.vertical, SpacingTokens.xxs)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(isFocused ? Color.accentColor : Color.accentColor.opacity(0.3), lineWidth: isFocused ? 1 : 0.5)
        )
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}