import SwiftUI

/// Shared toolbar layout for tab content areas (Activity Monitor, Query Store, Maintenance, etc.)
/// Provides a consistent horizontal bar with section picker on the left and controls on the right.
struct TabSectionToolbar<SectionPicker: View, Controls: View>: View {
    @ViewBuilder let sectionPicker: () -> SectionPicker
    @ViewBuilder let controls: () -> Controls

    var body: some View {
        HStack(spacing: SpacingTokens.sm) {
            sectionPicker()

            Spacer()

            controls()
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
    }
}

extension TabSectionToolbar where Controls == EmptyView {
    init(@ViewBuilder sectionPicker: @escaping () -> SectionPicker) {
        self.sectionPicker = sectionPicker
        self.controls = { EmptyView() }
    }
}
