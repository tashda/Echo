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
        VStack(spacing: 4) {
            AppearancePreviewThumbnail(mode: mode)
                .frame(width: 54, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.extraSmall, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.extraSmall, style: .continuous)
                        .strokeBorder(isSelected ? ColorTokens.accent : Color.primary.opacity(0.1), lineWidth: isSelected ? 2 : 0.5)
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
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            (isDark ? Color(white: 0.15) : Color(white: 0.96))
            
            VStack(alignment: .leading, spacing: 1) {
                // Header
                (isDark ? Color(white: 0.25) : Color(white: 0.85))
                    .frame(height: 6)
                    .overlay(alignment: .leading) {
                        HStack(spacing: 1.5) {
                            Circle().fill(Color.red.opacity(0.5)).frame(width: 2, height: 2)
                            Circle().fill(Color.yellow.opacity(0.5)).frame(width: 2, height: 2)
                            Circle().fill(Color.green.opacity(0.5)).frame(width: 2, height: 2)
                        }
                        .padding(.leading, 3)
                    }
                
                HStack(spacing: 1.5) {
                    // Sidebar
                    (isDark ? Color(white: 0.18) : Color(white: 0.92))
                        .frame(width: 12)
                    
                    // Content
                    VStack(alignment: .leading, spacing: 2) {
                        RoundedRectangle(cornerRadius: 0.5).fill(ColorTokens.accent.opacity(0.4)).frame(width: 20, height: 3)
                        RoundedRectangle(cornerRadius: 0.5).fill(Color.primary.opacity(0.08)).frame(width: 28, height: 1.5)
                        RoundedRectangle(cornerRadius: 0.5).fill(Color.primary.opacity(0.08)).frame(width: 25, height: 1.5)
                    }
                    .padding(3)
                }
            }
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
        VStack(spacing: 4) {
            previewThumbnail
                .frame(width: 54, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.extraSmall, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.extraSmall, style: .continuous)
                        .strokeBorder(isSelected ? ColorTokens.accent : Color.primary.opacity(0.1), lineWidth: isSelected ? 2 : 0.5)
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
            
            VStack(alignment: .leading, spacing: 3) {
                previewRow(icon: "cylinder.fill", color: mode == .colorful ? .blue : .primary.opacity(0.6))
                previewRow(icon: "tablecells.fill", color: mode == .colorful ? .orange : .primary.opacity(0.6))
                previewRow(icon: "eye.fill", color: mode == .colorful ? .purple : .primary.opacity(0.6))
            }
            .padding(.leading, 8)
        }
    }
    
    private func previewRow(icon: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 6))
                .foregroundStyle(color)
                .frame(width: 6)
            
            RoundedRectangle(cornerRadius: 0.5)
                .fill(Color.primary.opacity(0.12))
                .frame(width: 25, height: 2)
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
                                .padding(-3)
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

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.medium, style: .continuous)
                .fill(Color(white: 0.12)) // Professional dark editor background
                .overlay(
                    RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.medium, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Group {
                    (Text("SELECT")
                        .foregroundStyle(Color(red: 0.8, green: 0.5, blue: 0.9)) +
                    Text(" * ")
                        .foregroundStyle(Color(white: 0.9)) +
                    Text("FROM")
                        .foregroundStyle(Color(red: 0.8, green: 0.5, blue: 0.9)) +
                    Text(" users"))
                    
                    (Text("WHERE")
                        .foregroundStyle(Color(red: 0.8, green: 0.5, blue: 0.9)) +
                    Text(" created_at > ")
                        .foregroundStyle(Color(white: 0.9)) +
                    Text("'2026-03-17'")
                        .foregroundStyle(Color(red: 0.6, green: 0.8, blue: 0.5)))
                    
                    (Text("ORDER BY")
                        .foregroundStyle(Color(red: 0.8, green: 0.5, blue: 0.9)) +
                    Text(" id ")
                        .foregroundStyle(Color(white: 0.9)) +
                    Text("DESC")
                        .foregroundStyle(Color(red: 0.8, green: 0.5, blue: 0.9)))
                }
                .font(Font.custom(fontName, size: fontSize))
                .tracking(0.2)
            }
            .padding(16)
        }
        .frame(height: 120)
    }
}
