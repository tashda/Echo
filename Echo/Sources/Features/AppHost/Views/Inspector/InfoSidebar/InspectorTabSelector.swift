import SwiftUI

struct InspectorTabSelector: View {
    @Binding var selectedTab: InspectorTab

    var body: some View {
        let controlHeight: CGFloat = WorkspaceChromeMetrics.chromeBackgroundHeight
        let controlCornerRadius: CGFloat = controlHeight / 2
        let segmentCornerRadius: CGFloat = controlCornerRadius - 4

        RoundedRectangle(cornerRadius: controlCornerRadius, style: .continuous)
            .fill(ColorTokens.Text.primary.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: controlCornerRadius, style: .continuous)
                    .stroke(ColorTokens.Text.primary.opacity(0.08), lineWidth: 0.5)
            )
            .overlay(
                HStack(spacing: 0) {
                    ForEach(Array(InspectorTab.allCases.enumerated()), id: \.offset) { index, tab in
                        let isEdgeSegment = index == 0 || index == InspectorTab.allCases.count - 1
                        let highlightCornerRadius = isEdgeSegment ? controlCornerRadius : segmentCornerRadius

                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedTab = tab
                            }
                        } label: {
                            ZStack {
                                Rectangle()
                                    .fill(Color.clear)
                                    .contentShape(Rectangle())

                                Image(systemName: selectedTab == tab ? tab.activeIcon : tab.icon)
                                    .font(TypographyTokens.prominent.weight(selectedTab == tab ? .medium : .regular))
                                    .foregroundStyle(selectedTab == tab ? Color.white : ColorTokens.Text.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .background(
                            RoundedRectangle(cornerRadius: highlightCornerRadius, style: .continuous)
                                .fill(ColorTokens.accent)
                                .opacity(selectedTab == tab ? 1 : 0)
                                .animation(.easeInOut(duration: 0.15), value: selectedTab)
                        )
                        .help(tab.title)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        if index < InspectorTab.allCases.count - 1 {
                            let shouldShowDivider = selectedTab != tab &&
                                selectedTab != InspectorTab.allCases[index + 1]

                            Rectangle()
                                .fill(ColorTokens.Text.primary.opacity(0.12))
                                .frame(width: 0.5)
                                .opacity(shouldShowDivider ? 1 : 0)
                                .animation(.easeInOut(duration: 0.15), value: shouldShowDivider)
                        }
                    }
                }
                .padding(.horizontal, 0)
                .padding(.vertical, 0)
            )
            .frame(height: controlHeight)
    }
}
