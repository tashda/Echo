#if os(macOS)
import AppKit
#endif
import SwiftUI

extension TableStructureEditorView {

    internal var reloadButton: some View {
        Button {
            Task { await viewModel.reload() }
        } label: {
            HStack(spacing: 10) {
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(TypographyTokens.standard.weight(.semibold))
                        .symbolRenderingMode(.hierarchical)
                }

                Text(viewModel.isLoading ? "Reloading…" : "Reload")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, SpacingTokens.xs2)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .fill(accentColor.opacity(viewModel.isLoading ? 0.18 : 0.1))
                    )
            )
            .overlay(
                Capsule()
                    .stroke(accentColor.opacity(viewModel.isLoading ? 0.65 : 0.35), lineWidth: 1)
            )
            .foregroundColor(accentColor)
            .shadow(color: Color.black.opacity(0.12), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isApplying)
        .opacity(viewModel.isApplying ? 0.55 : 1)
        .animation(.easeInOut(duration: 0.25), value: viewModel.isLoading)
        .animation(.easeInOut(duration: 0.25), value: viewModel.isApplying)
        .help("Reload table structure")
    }

    internal var applyButton: some View {
        let isActive = viewModel.hasPendingChanges || viewModel.isApplying
        let isEnabled = viewModel.hasPendingChanges && !viewModel.isApplying

        return Button(action: applyChanges) {
            HStack(spacing: 10) {
                if viewModel.isApplying {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(applyActiveForegroundColor)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(TypographyTokens.standard.weight(.semibold))
                        .symbolRenderingMode(.hierarchical)
                }

                Text(viewModel.isApplying ? "Applying…" : "Apply")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .background {
                ZStack {
                    Capsule()
                        .fill(.ultraThinMaterial)
                    if isActive {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        accentColor.opacity(0.9),
                                        accentColor.opacity(0.7)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            }
            .overlay(
                Capsule()
                    .stroke(
                        isActive ? accentColor.opacity(0.75) : Color.white.opacity(0.2),
                        lineWidth: isActive ? 1.4 : 1
                    )
            )
            .foregroundColor(isActive ? applyActiveForegroundColor : Color.secondary)
            .shadow(color: isActive ? accentColor.opacity(0.4) : Color.black.opacity(0.08), radius: isActive ? 18 : 8, y: isActive ? 10 : 4)
            .scaleEffect(isActive ? 1.04 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: viewModel.hasPendingChanges)
        .animation(.easeInOut(duration: 0.25), value: viewModel.isApplying)
        .keyboardShortcut(.return, modifiers: [.command, .shift])
        .help(isEnabled ? "Apply pending changes (⇧⌘⏎)" : "No changes to apply")
    }

    #if os(macOS)
    internal var accentNSColor: NSColor {
        if projectStore.globalSettings.useServerColorAsAccent {
            return NSColor(tab.connection.color)
        }
        return NSColor.controlAccentColor
    }

    internal var accentColor: Color { Color(nsColor: accentNSColor) }

    internal var applyActiveForegroundColor: Color {
        let workingColor = accentNSColor.usingColorSpace(.extendedSRGB) ?? accentNSColor
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        workingColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return luminance > 0.6 ? Color.black.opacity(0.85) : Color.white
    }
    #else
    internal var accentColor: Color {
        projectStore.globalSettings.useServerColorAsAccent ? tab.connection.color : .accentColor
    }

    internal var applyActiveForegroundColor: Color {
        guard let cgColor = accentColor.cgColor,
              let srgbSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let converted = cgColor.converted(to: srgbSpace, intent: .defaultIntent, options: nil),
              let components = converted.components else {
            return .white
        }

        let componentCount = converted.numberOfComponents
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat

        if componentCount >= 3 {
            red = components[0]
            green = components[1]
            blue = components[2]
        } else {
            red = components[0]
            green = components[0]
            blue = components[0]
        }

        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return luminance > 0.6 ? Color.black.opacity(0.85) : Color.white
    }
    #endif

    internal var inlineButtonBackground: Color {
        ColorTokens.Background.secondary.opacity(0.2)
    }

    internal var headerBackgroundColor: Color {
        ColorTokens.Background.secondary
    }

    internal var headerBorderColor: Color {
        ColorTokens.Text.primary.opacity(appearanceStore.effectiveColorScheme == .dark ? 0.35 : 0.12)
    }

    internal var headerPrimaryColor: Color {
        ColorTokens.Text.primary
    }

    internal var headerSecondaryColor: Color {
        ColorTokens.Text.primary.opacity(appearanceStore.effectiveColorScheme == .dark ? 0.7 : 0.55)
    }
}
