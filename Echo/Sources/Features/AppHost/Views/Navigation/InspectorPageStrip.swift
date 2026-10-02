import SwiftUI

/// The inspector's pages (round IC, B1): the tab strip's plate in miniature, on the tab strip's
/// line above the inspector card. The shown page sits on the white raised plate with its icon
/// filled and its name; the others are icons, as squeezed tabs are. The plate glides like the tab
/// strip's (`EchoMotion.glide`). There is no unread count here: it lives on the toolbar bell. The
/// one mark is a dot on Details when a passive selection arrived while another page showed.
struct InspectorPageStrip: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.echoMotion) private var motion
    @Namespace private var plate

    private var inset: CGFloat { (WorkspaceChromeMetrics.chromeBackgroundHeight - WorkspaceChromeMetrics.tabHeight) / 2 }

    var body: some View {
        HStack(spacing: SpacingTokens.xxxs) {
            ForEach(InspectorPage.allCases) { page in
                segment(page)
            }
        }
        .padding(.horizontal, inset)
        .frame(maxWidth: .infinity)
        .frame(height: WorkspaceChromeMetrics.chromeBackgroundHeight)
        .background(
            TabStripBackground(style: .standard(colorScheme),
                               height: WorkspaceChromeMetrics.chromeBackgroundHeight,
                               cornerRadius: LayoutTokens.InspectorStrip.plateCornerRadius)
        )
        .animation(motion.glide, value: appState.inspectorPage)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Inspector pages")
    }

    private func segment(_ page: InspectorPage) -> some View {
        let isShown = appState.inspectorPage == page
        let marksDetails = page == .details && appState.hasUnseenDetails && !isShown
        return Button {
            appState.showInspectorPage(page)
        } label: {
            label(page, isShown: isShown)
                .frame(minWidth: LayoutTokens.InspectorStrip.iconSlotWidth,
                       maxWidth: isShown ? .infinity : LayoutTokens.InspectorStrip.iconSlotMaxWidth)
                .frame(height: WorkspaceChromeMetrics.tabHeight)
                .background {
                    if isShown {
                        TabRaisedPlate().matchedGeometryEffect(id: "plate", in: plate)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if marksDetails {
                        Circle()
                            .fill(ColorTokens.accent)
                            .frame(width: LayoutTokens.InspectorStrip.dotSize, height: LayoutTokens.InspectorStrip.dotSize)
                            .padding(.top, SpacingTokens.xxs)
                            .padding(.trailing, SpacingTokens.xxs2)
                            .transition(.opacity)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .layoutPriority(isShown ? 1 : 0)
        .help(help(page, marksDetails: marksDetails))
        .accessibilityLabel(page.title)
        .accessibilityAddTraits(isShown ? .isSelected : [])
    }

    /// The shown page carries its name when the column has room; otherwise only its icon.
    private func label(_ page: InspectorPage, isShown: Bool) -> some View {
        let icon = Image(systemName: isShown ? "\(page.systemImage).fill" : page.systemImage)
        return Group {
            if isShown {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: SpacingTokens.xxs2) {
                        icon
                        Text(page.title).lineLimit(1)
                    }
                    icon
                }
            } else {
                icon
            }
        }
        .font(TypographyTokens.caption2.weight(.medium))
        .foregroundStyle(isShown ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
        .padding(.horizontal, SpacingTokens.xs)
    }

    private func help(_ page: InspectorPage, marksDetails: Bool) -> String {
        let name = marksDetails ? "\(page.title), new selection" : page.title
        return "\(name) (⌥⌘\(page.shortcutDigit))"
    }
}

extension LayoutTokens {
    /// The inspector's page strip (round IC, B1).
    enum InspectorStrip {
        /// The tab strip's base plate corner.
        static let plateCornerRadius: CGFloat = 14
        /// A page shown as an icon takes at least this, at most `iconSlotMaxWidth`.
        static let iconSlotWidth: CGFloat = SpacingTokens.xl
        static let iconSlotMaxWidth: CGFloat = SpacingTokens.xl2 + SpacingTokens.xxs
        /// The dot on Details for a selection made while another page showed.
        static let dotSize: CGFloat = SpacingTokens.xxs2
    }
}
