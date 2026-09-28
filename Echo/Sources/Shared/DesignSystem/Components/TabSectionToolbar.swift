import SwiftUI

/// Shared toolbar layout for tab content areas (Activity Monitor, Query Store, Maintenance, etc.)
/// Provides a consistent horizontal bar with primary content on the left and controls on the right.
struct TabSectionToolbar<SectionPicker: View, Controls: View>: View {
    @ViewBuilder let sectionPicker: () -> SectionPicker
    @ViewBuilder let controls: () -> Controls

    var body: some View {
        HStack(spacing: SpacingTokens.sm) {
            sectionPicker()

            Spacer()

            controls()
        }
        .padding(.horizontal, SpacingTokens.lg)
        .padding(.vertical, SpacingTokens.xs)
    }
}

/// Toolbar layout for page-level navigation that remains visually centered while
/// optional contextual controls stay aligned to the trailing edge.
struct CenteredTabSectionToolbar<CenterContent: View, Controls: View>: View {
    @ViewBuilder let centerContent: () -> CenterContent
    @ViewBuilder let controls: () -> Controls

    init(
        @ViewBuilder _ centerContent: @escaping () -> CenterContent,
        @ViewBuilder controls: @escaping () -> Controls
    ) {
        self.centerContent = centerContent
        self.controls = controls
    }

    var body: some View {
        CenteredTabSectionLayout(centerContent, controls: controls)
            .padding(.horizontal, SpacingTokens.lg)
            .padding(.vertical, SpacingTokens.xs)
    }
}

/// Centers navigation independently of trailing actions without adding toolbar padding.
struct CenteredTabSectionLayout<CenterContent: View, Controls: View>: View {
    @ViewBuilder let centerContent: () -> CenterContent
    @ViewBuilder let controls: () -> Controls

    init(
        @ViewBuilder _ centerContent: @escaping () -> CenterContent,
        @ViewBuilder controls: @escaping () -> Controls
    ) {
        self.centerContent = centerContent
        self.controls = controls
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            CenteredTabSectionBarLayout(spacing: SpacingTokens.sm) {
                HStack {
                    centerContent()
                }

                HStack(spacing: SpacingTokens.sm) {
                    controls()
                }
            }

            VStack(spacing: SpacingTokens.xs) {
                centerContent()

                HStack(spacing: SpacingTokens.sm) {
                    Spacer(minLength: 0)
                    controls()
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Keeps the navigation exactly centered while reserving equal clearance for
/// contextual controls on both sides. `ViewThatFits` selects the stacked
/// alternative above when that clearance is unavailable.
private struct CenteredTabSectionBarLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard subviews.count == 2 else { return .zero }

        let centerSize = subviews[0].sizeThatFits(.unspecified)
        let controlsSize = subviews[1].sizeThatFits(.unspecified)
        let requiredWidth = centerSize.width + ((controlsSize.width + spacing) * 2)

        return CGSize(
            width: max(proposal.width ?? requiredWidth, requiredWidth),
            height: max(centerSize.height, controlsSize.height)
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard subviews.count == 2 else { return }

        let centerSize = subviews[0].sizeThatFits(.unspecified)
        let controlsSize = subviews[1].sizeThatFits(.unspecified)

        subviews[0].place(
            at: CGPoint(x: bounds.midX, y: bounds.midY),
            anchor: .center,
            proposal: ProposedViewSize(width: centerSize.width, height: centerSize.height)
        )
        subviews[1].place(
            at: CGPoint(x: bounds.maxX, y: bounds.midY),
            anchor: .trailing,
            proposal: ProposedViewSize(width: controlsSize.width, height: controlsSize.height)
        )
    }
}

extension CenteredTabSectionToolbar where Controls == EmptyView {
    init(@ViewBuilder _ centerContent: @escaping () -> CenterContent) {
        self.init(centerContent, controls: { EmptyView() })
    }
}

/// The canonical picker for mutually exclusive page sections.
/// It uses native tab navigation through six destinations and follows Apple's
/// menu recommendation when a page has more destinations than can fit as tabs.
struct TabSectionPicker<SelectionValue: Hashable, Content: View>: View {
    let title: LocalizedStringKey
    @Binding var selection: SelectionValue
    let itemCount: Int
    @ViewBuilder let content: () -> Content

    init(
        _ title: LocalizedStringKey,
        selection: Binding<SelectionValue>,
        itemCount: Int,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self._selection = selection
        self.itemCount = itemCount
        self.content = content
    }

    var body: some View {
        if itemCount > LayoutTokens.TabNavigation.maximumVisibleTabCount {
            overflowPicker
        } else {
            ViewThatFits(in: .horizontal) {
                picker
                    .tabSectionPickerStyle()
                    .frame(width: LayoutTokens.TabNavigation.pickerWidth(itemCount: itemCount))

                overflowPicker
            }
        }
    }

    private var overflowPicker: some View {
        picker
            .pickerStyle(.menu)
            .controlSize(.large)
            .fixedSize()
    }

    private var picker: some View {
        Picker(selection: $selection, content: content) {
            Text(title)
        }
        .labelsHidden()
    }
}

extension TabSectionToolbar where Controls == EmptyView {
    init(@ViewBuilder sectionPicker: @escaping () -> SectionPicker) {
        self.sectionPicker = sectionPicker
        self.controls = { EmptyView() }
    }
}
