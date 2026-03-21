import SwiftUI

/// Finder-style section header for sidebar groupings.
///
/// Renders a bold label with optional trailing content and disclosure chevron.
/// Used for top-level organizational groupings like server names.
public struct SidebarSectionHeader<Trailing: View>: View {
    public let title: String
    public var isExpanded: Binding<Bool>? = nil
    @ViewBuilder public var trailing: () -> Trailing

    public init(title: String, isExpanded: Binding<Bool>? = nil, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.isExpanded = isExpanded
        self.trailing = trailing
    }

    public var body: some View {
        HStack(spacing: SidebarRowConstants.iconTextSpacing) {
            Text(title)
                .font(SidebarRowConstants.sectionHeaderFont)
                .foregroundStyle(ColorTokens.Text.secondary)

            Spacer(minLength: SpacingTokens.xxs)

            trailing()

            if let isExpanded {
                Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(ColorTokens.Text.quaternary)
            }
        }
        .padding(.leading, SidebarRowConstants.chevronWidth + SidebarRowConstants.iconTextSpacing + SidebarRowConstants.rowLeadingPadding)
        .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
        .padding(.top, SpacingTokens.sm)
        .padding(.bottom, SpacingTokens.xxxs)
        .padding(.horizontal, SidebarRowConstants.rowOuterHorizontalPadding)
        .contentShape(Rectangle())
    }
}

// MARK: - Convenience initializer (no trailing content)

extension SidebarSectionHeader where Trailing == EmptyView {
    public init(title: String, isExpanded: Binding<Bool>? = nil) {
        self.title = title
        self.isExpanded = isExpanded
        self.trailing = { EmptyView() }
    }

    /// Legacy initializer for backward compatibility.
    public init(title: String, depth: Int = 0, count: Int? = nil, isExpanded: Binding<Bool>? = nil) {
        self.title = title
        self.isExpanded = isExpanded
        self.trailing = { EmptyView() }
    }
}
