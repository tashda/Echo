import SwiftUI

extension View {
    /// Makes a workspace tab fill its host instead of collapsing to the
    /// intrinsic size of an empty, loading, or error state.
    func tabContentFrame(alignment: Alignment = .top) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }
}
