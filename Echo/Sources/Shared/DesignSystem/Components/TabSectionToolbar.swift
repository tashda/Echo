import SwiftUI

extension EnvironmentValues {
    /// A tab toolbar's side inset: roomy inside a card, the tool header's own inset once the
    /// toolbar sits on the canvas above a tool's pane cards (TT1).
    @Entry var tabSectionToolbarInset: CGFloat = SpacingTokens.lg
}

extension View {
    /// Lines a tab toolbar up with the tool header, for a toolbar on the canvas.
    func tabSectionToolbarOnCanvas() -> some View {
        environment(\.tabSectionToolbarInset, SpacingTokens.xs)
    }
}

/// Shared toolbar layout for tab content areas (Activity Monitor, Query Store, Maintenance, etc.)
/// Provides a consistent horizontal bar with primary content on the left and controls on the right.
struct TabSectionToolbar<SectionPicker: View, Controls: View>: View {
    @ViewBuilder let sectionPicker: () -> SectionPicker
    @ViewBuilder let controls: () -> Controls

    @Environment(\.tabSectionToolbarInset) private var inset

    var body: some View {
        HStack(spacing: SpacingTokens.sm) {
            sectionPicker()

            Spacer()

            controls()
        }
        .padding(.horizontal, inset)
        .padding(.vertical, SpacingTokens.xs)
    }
}

/// Toolbar layout for page-level navigation that remains visually centered while
/// optional contextual controls stay aligned to the trailing edge.
struct CenteredTabSectionToolbar<CenterContent: View, Controls: View>: View {
    @ViewBuilder let centerContent: () -> CenterContent
    @ViewBuilder let controls: () -> Controls

    @Environment(\.tabSectionToolbarInset) private var inset

    init(
        @ViewBuilder _ centerContent: @escaping () -> CenterContent,
        @ViewBuilder controls: @escaping () -> Controls
    ) {
        self.centerContent = centerContent
        self.controls = controls
    }

    var body: some View {
        CenteredTabSectionLayout(centerContent, controls: controls)
            .padding(.horizontal, inset)
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
        // One layout that centres or stacks, rather than a `ViewThatFits` holding both: that built
        // and measured the navigation twice, which made opening a tool tab stall for 0.3-0.6 s.
        CenteredTabSectionBarLayout(spacing: SpacingTokens.sm, stackedSpacing: SpacingTokens.xs) {
            HStack {
                centerContent()
            }

            HStack(spacing: SpacingTokens.sm) {
                controls()
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Keeps the navigation exactly centered while reserving equal clearance for contextual controls
/// on both sides. Without room for that clearance, the controls go below, at the trailing edge.
/// Each subview is measured once per layout pass (the cache).
struct CenteredTabSectionBarLayout: Layout {
    let spacing: CGFloat
    let stackedSpacing: CGFloat

    struct Sizes {
        var center: CGSize
        var controls: CGSize
        var spacing = ViewSpacing()
    }

    func makeCache(subviews: Subviews) -> Sizes? {
        guard subviews.count == 2 else { return nil }
        var spacing = subviews[0].spacing
        spacing.formUnion(subviews[1].spacing)
        return Sizes(center: subviews[0].sizeThatFits(.unspecified), controls: subviews[1].sizeThatFits(.unspecified),
                     spacing: spacing)
    }

    /// The subviews' spacing, worked out once with the sizes (the default asks them every time).
    func spacing(subviews: Subviews, cache: inout Sizes?) -> ViewSpacing {
        cache?.spacing ?? ViewSpacing()
    }

    func updateCache(_ cache: inout Sizes?, subviews: Subviews) {
        cache = makeCache(subviews: subviews)
    }

    /// The width that keeps the navigation centred with the controls clear of it.
    static func centredWidth(_ sizes: Sizes, spacing: CGFloat) -> CGFloat {
        sizes.center.width + (sizes.controls.width + spacing) * 2
    }

    static func isStacked(_ sizes: Sizes, width: CGFloat?, spacing: CGFloat) -> Bool {
        guard let width, sizes.controls.width > 0 else { return false }
        return width < centredWidth(sizes, spacing: spacing)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Sizes?) -> CGSize {
        guard let sizes = cache else { return .zero }
        if Self.isStacked(sizes, width: proposal.width, spacing: spacing) {
            return CGSize(
                width: proposal.width ?? max(sizes.center.width, sizes.controls.width),
                height: sizes.center.height + stackedSpacing + sizes.controls.height
            )
        }
        let requiredWidth = Self.centredWidth(sizes, spacing: spacing)
        return CGSize(
            width: max(proposal.width ?? requiredWidth, requiredWidth),
            height: max(sizes.center.height, sizes.controls.height)
        )
    }

    // Nothing aligns to the bar's guides; the default answers by placing and measuring the
    // subviews again on every query.
    func explicitAlignment(of guide: HorizontalAlignment, in bounds: CGRect, proposal: ProposedViewSize,
                           subviews: Subviews, cache: inout Sizes?) -> CGFloat? { nil }

    func explicitAlignment(of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize,
                           subviews: Subviews, cache: inout Sizes?) -> CGFloat? { nil }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Sizes?) {
        guard let sizes = cache else { return }
        let center = ProposedViewSize(sizes.center)
        let controls = ProposedViewSize(sizes.controls)
        if Self.isStacked(sizes, width: bounds.width, spacing: spacing) {
            // The full width, so a picker that doesn't fit can turn into its menu.
            subviews[0].place(at: CGPoint(x: bounds.midX, y: bounds.minY), anchor: .top,
                              proposal: ProposedViewSize(width: bounds.width, height: sizes.center.height))
            subviews[1].place(at: CGPoint(x: bounds.maxX, y: bounds.maxY), anchor: .bottomTrailing, proposal: controls)
        } else {
            subviews[0].place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center, proposal: center)
            subviews[1].place(at: CGPoint(x: bounds.maxX, y: bounds.midY), anchor: .trailing, proposal: controls)
        }
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
