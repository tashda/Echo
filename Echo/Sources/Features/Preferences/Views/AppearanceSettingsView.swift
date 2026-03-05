import SwiftUI
import Foundation
import AppKit

struct AppearanceSettingsView: View {
    @Environment(ProjectStore.self) private var projectStore
    @EnvironmentObject private var appearanceStore: AppearanceStore

    var body: some View {
        Form {
            appearanceModeSection
            accentColorSection
            editorFontSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Sections

    private var appearanceModeSection: some View {
        Section {
            AppearanceModePicker(selection: appearanceModeBinding)

            Text("Choose Light or Dark for a fixed appearance, or System to follow macOS automatically.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var accentColorSection: some View {
        Section("Accent Color") {
            Toggle("Use Server Color as Accent", isOn: Binding(
                get: { projectStore.globalSettings.useServerColorAsAccent },
                set: { newValue in
                    var settings = projectStore.globalSettings
                    settings.useServerColorAsAccent = newValue
                    Task { try? await projectStore.updateGlobalSettings(settings) }
                }
            ))

            if projectStore.globalSettings.useServerColorAsAccent {
                Text("The accent color changes based on the active database connection.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                AccentColorPalette(selection: customAccentColorHexBinding)
            }
        }
    }

    private var editorFontSection: some View {
        Section("Editor Font") {
            MonospacedFontPicker(
                selectedFamily: Binding(
                    get: { projectStore.globalSettings.defaultEditorFontFamily },
                    set: { newValue in
                        var settings = projectStore.globalSettings
                        settings.defaultEditorFontFamily = newValue
                        Task { try? await projectStore.updateGlobalSettings(settings) }
                    }
                ),
                fontSize: projectStore.globalSettings.defaultEditorFontSize
            )

            LabeledContent("Font Size") {
                Stepper(
                    "\(String(format: "%.1f", projectStore.globalSettings.defaultEditorFontSize)) pt",
                    value: Binding(
                        get: { projectStore.globalSettings.defaultEditorFontSize },
                        set: { newValue in
                            var settings = projectStore.globalSettings
                            settings.defaultEditorFontSize = newValue
                            Task { try? await projectStore.updateGlobalSettings(settings) }
                        }
                    ),
                    in: 8...24,
                    step: 0.5
                )
            }

            Toggle("Enable Ligatures", isOn: Binding(
                get: { projectStore.globalSettings.fontLigatureOverrides[projectStore.globalSettings.defaultEditorFontFamily] ?? true },
                set: { newValue in
                    var settings = projectStore.globalSettings
                    settings.fontLigatureOverrides[projectStore.globalSettings.defaultEditorFontFamily] = newValue
                    Task { try? await projectStore.updateGlobalSettings(settings) }
                }
            ))
        }
    }

    // MARK: - Bindings

    private var appearanceModeBinding: Binding<AppearanceMode> {
        Binding(
            get: { projectStore.globalSettings.appearanceMode },
            set: { newValue in
                var settings = projectStore.globalSettings
                settings.appearanceMode = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
                appearanceStore.applyAppearanceMode(newValue)
            }
        )
    }

    private var customAccentColorHexBinding: Binding<String> {
        Binding(
            get: { projectStore.globalSettings.customAccentColorHex ?? "" },
            set: { newHex in
                var settings = projectStore.globalSettings
                settings.customAccentColorHex = newHex.isEmpty ? nil : newHex
                Task { try? await projectStore.updateGlobalSettings(settings) }
                if let color = Color(hex: newHex) {
                    appearanceStore.setAccentColor(color)
                }
            }
        )
    }
}

// MARK: - Appearance Mode Picker with Previews

private struct AppearanceModePicker: View {
    @Binding var selection: AppearanceMode

    var body: some View {
        HStack(spacing: SpacingTokens.sm) {
            ForEach(AppearanceMode.allCases, id: \.self) { mode in
                AppearanceModeCard(mode: mode, isSelected: selection == mode)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) { selection = mode }
                    }
            }
        }
        .padding(.vertical, SpacingTokens.xxs)
    }
}

private struct AppearanceModeCard: View {
    let mode: AppearanceMode
    let isSelected: Bool

    private var previewScheme: ColorScheme? {
        switch mode {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    var body: some View {
        VStack(spacing: SpacingTokens.xs) {
            previewThumbnail
                .frame(width: 120, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2.5)
                )
                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)

            Text(mode.displayName)
                .font(TypographyTokens.caption2.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private var previewThumbnail: some View {
        ZStack {
            switch mode {
            case .light:
                miniWindowPreview(bg: Color(white: 0.96), sidebar: Color(white: 0.91), content: Color.white)
            case .dark:
                miniWindowPreview(bg: Color(white: 0.15), sidebar: Color(white: 0.12), content: Color(white: 0.18))
            case .system:
                HStack(spacing: 0) {
                    miniWindowPreview(bg: Color(white: 0.96), sidebar: Color(white: 0.91), content: Color.white)
                        .clipShape(Rectangle())
                    miniWindowPreview(bg: Color(white: 0.15), sidebar: Color(white: 0.12), content: Color(white: 0.18))
                        .clipShape(Rectangle())
                }
            }
        }
    }

    private func miniWindowPreview(bg: Color, sidebar: Color, content: Color) -> some View {
        ZStack(alignment: .topLeading) {
            bg
            HStack(spacing: 0) {
                sidebar.frame(width: 30)
                VStack(spacing: 0) {
                    bg.frame(height: 10)
                    content
                }
            }
            // Traffic lights
            HStack(spacing: 2.5) {
                Circle().fill(Color.red.opacity(0.8)).frame(width: 5, height: 5)
                Circle().fill(Color.orange.opacity(0.8)).frame(width: 5, height: 5)
                Circle().fill(Color.green.opacity(0.8)).frame(width: 5, height: 5)
            }
            .padding(.top, 4)
            .padding(.leading, 5)
        }
    }
}

// MARK: - Accent Color Palette

private struct AccentColorPalette: View {
    @Binding var selection: String

    private static let presets: [(name: String, hex: String)] = [
        ("Blue", "5A9CDE"),
        ("Green", "6EAE72"),
        ("Orange", "E8943A"),
        ("Purple", "9B72CF"),
        ("Pink", "D4687A"),
    ]

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: selection) ?? .accentColor },
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
                    .fill(Color(hex: preset.hex) ?? .accentColor)
                    .frame(width: 22, height: 22)
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .overlay(Circle().strokeBorder(.primary.opacity(0.15), lineWidth: 0.5))
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
