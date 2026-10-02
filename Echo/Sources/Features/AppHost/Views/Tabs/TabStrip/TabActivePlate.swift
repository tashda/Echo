import SwiftUI

/// The front tab's raised plate: one shape under the strip that glides from tab to tab (round 49,
/// MO2), instead of each tab drawing its own when it becomes active.
struct TabActivePlate: View {
    let width: CGFloat
    let offset: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 15, style: .continuous) }

    var body: some View {
        let isDark = colorScheme == .dark
        shape
            .fill(LinearGradient(colors: isDark
                                 ? [ColorTokens.TabStrip.ActiveTab.Dark.top, ColorTokens.TabStrip.ActiveTab.Dark.bottom]
                                 : [ColorTokens.TabStrip.ActiveTab.Light.top, ColorTokens.TabStrip.ActiveTab.Light.bottom],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(shape.stroke(isDark ? ColorTokens.TabStrip.Border.activeDark : ColorTokens.TabStrip.Border.activeLight,
                                  lineWidth: tabHairlineWidth()))
            .shadow(color: isDark ? ColorTokens.TabStrip.Shadow.dark : ColorTokens.TabStrip.Shadow.light, radius: 2.5, y: 1.2)
            .frame(width: max(width, 0), height: WorkspaceChromeMetrics.tabHeight)
            .offset(x: offset)
            .allowsHitTesting(false)
    }
}
