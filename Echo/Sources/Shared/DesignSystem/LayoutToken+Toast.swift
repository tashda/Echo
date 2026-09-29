import CoreGraphics

extension LayoutTokens {
    /// Toasts (plan N2). An expanded toast takes the floating-surface medium width and corners.
    public enum Toast {
        /// A collapsed toast is a pill-like rounded rectangle, so the stack melts smoothly.
        public static let cornerRadius: CGFloat = 20
    }
}
