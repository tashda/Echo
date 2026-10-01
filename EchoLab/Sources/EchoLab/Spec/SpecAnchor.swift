import SwiftUI

/// Marks a part of a specimen with its element number so the Spec view can draw its ID on it.
struct SpecAnchorKey: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// `number` is the element number within the area, such as "2.4".
    ///
    /// The anchor is set from a background so a parent's anchor never replaces its children's.
    func specAnchor(_ number: String) -> some View {
        background {
            Color.clear.anchorPreference(key: SpecAnchorKey.self, value: .bounds) { [number: $0] }
        }
    }
}

extension EnvironmentValues {
    /// Opens the Feedback panel about one element: (full ID, element name).
    @Entry var labGiveFeedback: (String, String) -> Void = { _, _ in }
}
