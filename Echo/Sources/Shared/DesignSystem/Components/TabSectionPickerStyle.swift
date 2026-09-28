import SwiftUI

extension View {
    /// Uses the system's navigation-specific tab treatment when available while preserving
    /// the native segmented control on earlier supported versions of macOS.
    @ViewBuilder
    func tabSectionPickerStyle() -> some View {
        // `.tabs` only exists in the macOS 27 SDK; the compiler check keeps the project
        // building with Xcode 26 (used by CI).
        #if compiler(>=6.3)
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
