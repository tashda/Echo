import SwiftUI

extension View {
    /// Uses the system's navigation-specific tab treatment when available while preserving
    /// the native segmented control on earlier supported versions of macOS.
    @ViewBuilder
    func tabSectionPickerStyle() -> some View {
        if #available(macOS 27.0, *) {
            pickerStyle(.tabs)
                .controlSize(.large)
        } else {
            pickerStyle(.segmented)
        }
    }
}
