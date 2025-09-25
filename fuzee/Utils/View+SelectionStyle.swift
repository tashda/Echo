import SwiftUI

/// A view modifier that applies a selection style to a list row,
/// similar to Finder in recent versions of macOS.
///
/// When selected, the row background becomes a light grey, and the foreground
/// content (text and icons) is tinted with the app's accent color.
struct SidebarSelectionStyle: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .foregroundStyle(isSelected ? Color.accentColor : .primary)
            .listRowBackground(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color(.unemphasizedSelectedContentBackgroundColor))
                            .padding(.vertical, 2)
                            .padding(.horizontal, 4)
                    }
                }
            )
    }
}

extension View {
    /// A helper function to easily apply the sidebar list row selection style.
    func sidebarSelectionStyle(isSelected: Bool) -> some View {
        modifier(SidebarSelectionStyle(isSelected: isSelected))
    }
}
