import SwiftUI

extension View {
    /// A scrolling area must never decide the window's size. Without this, a long list reports
    /// its whole content height and the window cannot be made shorter than the list. A
    /// `GeometryReader` has no size of its own: it takes whatever the parent gives it.
    func labScrollSizing() -> some View {
        GeometryReader { proxy in
            self.frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}
