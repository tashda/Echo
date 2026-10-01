import SwiftUI

extension View {
    /// Uses the system's navigation-specific tab treatment when available while preserving
    /// the native segmented control on earlier supported versions of macOS.
    @ViewBuilder
    func tabSectionPickerStyle() -> some View {
        // `.tabs` only exists in the macOS 27 SDK. Xcode 26.x ships Swift 6.3, so this keeps the
        // project building with Xcode 26 (used by CI) while Xcode 27 still gets the tab style.
        #if compiler(>=6.4)
        if #available(macOS 27.0, *) {
            pickerStyle(.tabs)
                .controlSize(.large)
        } else {
            pickerStyle(.segmented)
        }
        #else
        pickerStyle(.segmented)
        #endif
    }
}
