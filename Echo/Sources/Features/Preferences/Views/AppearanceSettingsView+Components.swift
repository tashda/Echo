import SwiftUI
import AppKit

// MARK: - Appearance & Sidebar Icon Pickers (Tahoe Grouped Style)

struct AppearanceModePicker: View {
    @Binding var selection: AppearanceMode

    var body: some View {
        HStack(spacing: SpacingTokens.md) {
            ForEach(AppearanceMode.allCases, id: \.self) { mode in
                AppearanceModeCard(mode: mode, isSelected: selection == mode)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) { selection = mode }
                    }
            }
        }
    }
}

private struct AppearanceModeCard: View {
    let mode: AppearanceMode
    let isSelected: Bool

    var body: some View {
        VStack(spacing: SpacingTokens.xxs2) {
            AppearancePreviewThumbnail(mode: mode)
                .frame(width: 96, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.medium, style: .continuous)
                        .strokeBorder(isSelected ? ColorTokens.accent : Color.primary.opacity(0.12), lineWidth: isSelected ? 2.5 : 1)
                )
                .shadow(isSelected ? ShadowTokens.cardSelected : ShadowTokens.cardRest)

            Text(mode.displayName)
                .font(TypographyTokens.detail.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
        }
    }
}

private struct AppearancePreviewThumbnail: View {
    let mode: AppearanceMode
    
    var body: some View {
        ZStack {
            switch mode {
            case .light:
                AppearancePreviewBase(isDark: false)
            case .dark:
                AppearancePreviewBase(isDark: true)
            case .system:
                HStack(spacing: 0) {
                    AppearancePreviewBase(isDark: false)
                    AppearancePreviewBase(isDark: true)
                }
            }
        }
    }
}

private struct AppearancePreviewBase: View {
    let isDark: Bool

    private var wallpaperGradient: LinearGradient {
        isDark
            ? LinearGradient(
                colors: [Color(hue: 0.72, saturation: 0.55, brightness: 0.30), Color(hue: 0.62, saturation: 0.60, brightness: 0.18)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(
                colors: [Color(hue: 0.57, saturation: 0.28, brightness: 0.90), Color(hue: 0.68, saturation: 0.22, brightness: 0.82)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            wallpaperGradient

            // Floating window
            VStack(spacing: 0) {
                // Title bar
                HStack(spacing: SpacingTokens.xxxs1) {
                    Circle().fill(Color(red: 1.00, green: 0.37, blue: 0.34)).frame(width: SpacingTokens.nano1, height: SpacingTokens.nano1)
                    Circle().fill(Color(red: 1.00, green: 0.73, blue: 0.20)).frame(width: SpacingTokens.nano1, height: SpacingTokens.nano1)
                    Circle().fill(Color(red: 0.29, green: 0.78, blue: 0.35)).frame(width: SpacingTokens.nano1, height: SpacingTokens.nano1)
                    Spacer()
                }
                .padding(.leading, SpacingTokens.xxs2)
                .frame(maxWidth: .infinity)
                .frame(height: 11)
                .background(isDark ? Color(white: 0.24) : Color(white: 0.88))

                // Content area
                HStack(spacing: 0) {
                    (isDark ? Color(white: 0.19) : Color(white: 0.93)).frame(width: 18)
                    VStack(alignment: .leading, spacing: SpacingTokens.xxxs1) {
                        RoundedRectangle(cornerRadius: 0.5).fill(ColorTokens.accent.opacity(0.55)).frame(width: 26, height: 3)
                        RoundedRectangle(cornerRadius: 0.5).fill(Color.primary.opacity(0.10)).frame(width: 36, height: 2)
                        RoundedRectangle(cornerRadius: 0.5).fill(Color.primary.opacity(0.10)).frame(width: 30, height: 2)
                    }
                    .padding(.leading, SpacingTokens.xxs1).padding(.vertical, SpacingTokens.xxs)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(isDark ? Color(white: 0.16) : Color(white: 0.97))
            }
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .shadow(color: .black.opacity(isDark ? 0.4 : 0.18), radius: 4, x: 0, y: 2)
            .padding(.horizontal, SpacingTokens.xxs3)
            .padding(.bottom, SpacingTokens.xxs1)
        }
    }
}

struct SidebarIconPicker: View {
    @Binding var selection: SidebarIconColorMode

    var body: some View {
        HStack(spacing: SpacingTokens.md) {
            ForEach(SidebarIconColorMode.allCases, id: \.self) { mode in
                SidebarIconCard(mode: mode, isSelected: selection == mode)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) { selection = mode }
                    }
            }
        }
    }
}

private struct SidebarIconCard: View {
    let mode: SidebarIconColorMode
    let isSelected: Bool

    var body: some View {
        VStack(spacing: SpacingTokens.xxs2) {
            previewThumbnail
                .frame(width: 96, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.medium, style: .continuous)
                        .strokeBorder(isSelected ? ColorTokens.accent : Color.primary.opacity(0.12), lineWidth: isSelected ? 2.5 : 1)
                )
                .shadow(isSelected ? ShadowTokens.cardSelected : ShadowTokens.cardRest)

            Text(mode.displayName)
                .font(TypographyTokens.detail.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
        }
    }

    private var previewThumbnail: some View {
        ZStack(alignment: .leading) {
            ColorTokens.Background.secondary
            
            VStack(alignment: .leading, spacing: SpacingTokens.nano) {
                previewRow(icon: "cylinder.fill", color: mode == .colorful ? .blue : .primary.opacity(0.6))
                previewRow(icon: "tablecells.fill", color: mode == .colorful ? .orange : .primary.opacity(0.6))
                previewRow(icon: "eye.fill", color: mode == .colorful ? .purple : .primary.opacity(0.6))
            }
            .padding(.leading, SpacingTokens.xs)
        }
    }
    
    private func previewRow(icon: String, color: Color) -> some View {
        HStack(spacing: SpacingTokens.xxs) {
            Image(systemName: icon)
                .font(TypographyTokens.micro)
                .foregroundStyle(color)
                .frame(width: 6)
            
            RoundedRectangle(cornerRadius: 0.5)
                .fill(Color.primary.opacity(0.12))
                .frame(width: 25, height: 2)
        }
    }
}

// MARK: - Sidebar Density Picker

struct SidebarDensityPicker: View {
    @Binding var selection: SidebarDensity

    var body: some View {
        HStack(spacing: SpacingTokens.md) {
            ForEach(SidebarDensity.allCases, id: \.self) { density in
                SidebarDensityCard(density: density, isSelected: selection == density)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) { selection = density }
                    }
            }
        }
    }
}

private struct SidebarDensityCard: View {
    let density: SidebarDensity
    let isSelected: Bool

    var body: some View {
        VStack(spacing: SpacingTokens.xxs2) {
            previewThumbnail
                .frame(width: 96, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.medium, style: .continuous)
                        .strokeBorder(isSelected ? ColorTokens.accent : Color.primary.opacity(0.12), lineWidth: isSelected ? 2.5 : 1)
                )
                .shadow(isSelected ? ShadowTokens.cardSelected : ShadowTokens.cardRest)

            Text(density.displayName)
                .font(TypographyTokens.detail.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
        }
    }

    private var rowSpacing: CGFloat {
        switch density {
        case .small: return 2
        case .medium: return 4
        case .large: return 6
        }
    }

    private var rowHeight: CGFloat {
        switch density {
        case .small: return 3
        case .medium: return 4
        case .large: return 5
        }
    }

    private var previewThumbnail: some View {
        ZStack(alignment: .leading) {
            ColorTokens.Background.secondary
            VStack(alignment: .leading, spacing: rowSpacing) {
                densityRow(icon: "cylinder.fill")
                densityRow(icon: "tablecells.fill")
                densityRow(icon: "eye.fill")
            }
            .padding(.leading, SpacingTokens.xs)
        }
    }

    private func densityRow(icon: String) -> some View {
        let iconSize: CGFloat = {
            switch density {
            case .small: return 6
            case .medium: return 7
            case .large: return 8
            }
        }()
        
        return HStack(spacing: SpacingTokens.xxs) {
            Image(systemName: icon)
                .font(.system(size: iconSize))
                .foregroundStyle(Color.primary.opacity(0.55))
                .frame(width: iconSize)
            RoundedRectangle(cornerRadius: 0.5)
                .fill(Color.primary.opacity(0.12))
                .frame(width: 25, height: rowHeight)
        }
    }
}

// MARK: - Accent Color Palette

struct AccentColorPalette: View {
    @Binding var selection: String

    private static let presets: [(name: String, hex: String)] = [
        ("Blue", "007AFF"),
        ("Purple", "AF52DE"),
        ("Pink", "FF2D55"),
        ("Red", "FF3B30"),
        ("Orange", "FF9500"),
        ("Yellow", "FFCC00"),
        ("Green", "34C759"),
        ("Gray", "8E8E93"),
    ]

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: selection) ?? ColorTokens.accent },
            set: { color in
                if let hex = color.toHex() {
                    selection = hex.replacingOccurrences(of: "#", with: "")
                }
            }
        )
    }

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            ForEach(Self.presets, id: \.hex) { preset in
                let isSelected = selection.uppercased() == preset.hex.uppercased()
                Circle()
                    .fill(Color(hex: preset.hex) ?? ColorTokens.accent)
                    .frame(width: 24, height: 24)
                    .overlay {
                        if isSelected {
                            Circle()
                                .strokeBorder(ColorTokens.accent, lineWidth: 2)
                                .padding(-SpacingTokens.nano)
                        }
                    }
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5))
                    .contentShape(Circle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) { selection = preset.hex }
                    }
            }

            ColorPicker("", selection: colorBinding, supportsOpacity: false)
                .labelsHidden()
        }
    }
}

// MARK: - Editor Font Preview

struct EditorFontPreview: View {
    let fontName: String
    let fontSize: Double
    let ligatures: Bool

    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }
    private var bg: Color { isDark ? Color(white: 0.12) : Color(white: 0.94) }
    private var headerBg: Color { isDark ? Color(white: 0.18) : Color(white: 0.85) }
    private var keyword: Color { isDark ? Color(red: 0.8, green: 0.5, blue: 0.9) : Color(red: 0.55, green: 0.1, blue: 0.75) }
    private var plain: Color { isDark ? Color(white: 0.9) : Color(white: 0.12) }
    private var string: Color { isDark ? Color(red: 0.6, green: 0.8, blue: 0.5) : Color(red: 0.7, green: 0.1, blue: 0.1) }
    private var lineNumber: Color { isDark ? Color.white.opacity(0.22) : Color.black.opacity(0.25) }
    private var tabLabel: Color { isDark ? Color.white.opacity(0.45) : Color.black.opacity(0.45) }
    private var dotColor: Color { isDark ? string.opacity(0.7) : Color.green.opacity(0.7) }

    private var editorFont: Font {
        Font(NSFont(name: fontName, size: fontSize) ?? .monospacedSystemFont(ofSize: fontSize, weight: .regular))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: SpacingTokens.xs2) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 6, height: 6)
                Text("query.sql")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(tabLabel)
                Spacer()
            }
            .padding(.horizontal, SpacingTokens.sm)
            .frame(height: 28)
            .background(headerBg)

            // Code lines
            VStack(alignment: .leading, spacing: SpacingTokens.xxs1) {
                codeLine(number: 1, content: line1)
                codeLine(number: 2, content: line2)
                codeLine(number: 3, content: line3)
            }
            .font(editorFont)
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.vertical, SpacingTokens.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(bg)
        }
        .clipShape(RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.medium, style: .continuous)
                .strokeBorder(Color.primary.opacity(isDark ? 0.08 : 0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(isDark ? 0 : 0.06), radius: 4, x: 0, y: 2)
    }

    private func codeLine(number: Int, content: Text) -> some View {
        HStack(alignment: .top, spacing: SpacingTokens.xs) {
            Text("\(number)")
                .foregroundStyle(lineNumber)
                .frame(width: 16, alignment: .trailing)
            content
        }
    }

    private var line1: Text {
        Text("\(Text("SELECT").foregroundStyle(keyword))\(Text(" * ").foregroundStyle(plain))\(Text("FROM").foregroundStyle(keyword))\(Text(" users").foregroundStyle(plain))")
    }

    private var line2: Text {
        Text("\(Text("WHERE").foregroundStyle(keyword))\(Text(" created_at > ").foregroundStyle(plain))\(Text("'2026-03-17'").foregroundStyle(string))")
    }

    private var line3: Text {
        Text("\(Text("ORDER BY").foregroundStyle(keyword))\(Text(" id ").foregroundStyle(plain))\(Text("DESC").foregroundStyle(keyword))")
    }
}
