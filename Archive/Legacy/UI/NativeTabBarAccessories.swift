import SwiftUI
import AppKit

struct NativeTabBarAccessories: View {
    var body: some View {
        HStack(spacing: 6) {
            GlassButton(systemImage: "square.grid.2x2", action: toggleOverview)
            GlassButton(systemImage: "plus", action: newTab)
        }
    }

    private func toggleOverview() {
        if let window = NSApp.keyWindow as? TitlebarTabsWindow {
            window.onToggleTabOverview?()
        }
    }

    private func newTab() {
        if let window = NSApp.keyWindow as? TitlebarTabsWindow {
            window.onOpenNewTab?()
        }
    }
}

private struct GlassButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ForegroundStyle())
                .frame(width: 28, height: 24)
                .background(BackgroundShape().fill(BackgroundGradient()))
                .overlay(BackgroundShape().stroke(BorderGradient(), lineWidth: 1))
                .shadow(color: .black.opacity(0.28), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(systemImage == "plus" ? "New Tab" : "Tab Overview")
    }

    private struct BackgroundShape: Shape {
        func path(in rect: CGRect) -> Path {
            RoundedRectangle(cornerRadius: 7, style: .continuous).path(in: rect)
        }
    }

    private struct ForegroundStyle: ShapeStyle {
        func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
            LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(environment.colorScheme == .dark ? 0.92 : 0.78), location: 0.0),
                    .init(color: Color.white.opacity(environment.colorScheme == .dark ? 0.82 : 0.64), location: 0.48),
                    .init(color: Color.white.opacity(environment.colorScheme == .dark ? 0.72 : 0.54), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private struct BackgroundGradient: ShapeStyle {
        func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
            let top = Color.white.opacity(environment.colorScheme == .dark ? 0.16 : 0.38)
            let mid = Color.white.opacity(environment.colorScheme == .dark ? 0.10 : 0.28)
            let bottom = Color.white.opacity(environment.colorScheme == .dark ? 0.06 : 0.18)
            return LinearGradient(colors: [top, mid, bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private struct BorderGradient: ShapeStyle {
        func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
            LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(environment.colorScheme == .dark ? 0.25 : 0.55), location: 0.0),
                    .init(color: Color.white.opacity(environment.colorScheme == .dark ? 0.10 : 0.25), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
