import SwiftUI

/// A grouped-form row you type into (round MC): the label at the leading edge, the content filling
/// the rest, left-aligned and without a bordered box. The row is the field; a click anywhere in it
/// focuses the field (Design/05-components › Connections, inset rows).
struct InsetRow<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        HStack(spacing: SpacingTokens.sm) {
            Text(title)
                .foregroundStyle(ColorTokens.Text.primary)
                .frame(width: InsetRowMetrics.labelWidth, alignment: .leading)
            content()
                .textFieldStyle(.plain)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: InsetRowMetrics.minHeight)
        .contentShape(Rectangle())
    }
}

enum InsetRowMetrics {
    /// The label column: wide enough for "Database" and "User name" at the form's size.
    static let labelWidth: CGFloat = 96
    static let minHeight: CGFloat = 28
}
