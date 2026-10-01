import SwiftUI

extension ToolbarContent {
    /// Round 20 (V1): when the window is too narrow, the toolbar moves its neighbours into » first,
    /// so Run (and ■ while a query runs) stays in reach. The priority exists from macOS 26.1.
    @ToolbarContentBuilder
    func keptOutOfOverflow() -> some ToolbarContent {
        if #available(macOS 26.1, *) {
            visibilityPriority(.high)
        } else {
            self
        }
    }
}
