import AppKit
import SwiftUI

/// The frame every footer pill's popover shares (round 41.5): a title, an optional control at
/// its trailing edge, then the content, with the popover's padding and a fixed width.
struct FooterPopoverContent<Accessory: View, Content: View>: View {
    let title: String
    var width: CGFloat = LayoutTokens.FloatingSurface.smallWidth
    @ViewBuilder var accessory: () -> Accessory
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xs) {
                Text(title)
                    .font(TypographyTokens.headline)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: SpacingTokens.xs)
                accessory()
            }
            content()
        }
        .padding(SpacingTokens.md)
        .frame(width: width, alignment: .leading)
    }
}

extension FooterPopoverContent where Accessory == EmptyView {
    init(title: String, width: CGFloat = LayoutTokens.FloatingSurface.smallWidth, @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, width: width, accessory: { EmptyView() }, content: content)
    }
}

/// A label on the left and its value on the right in tabular digits; with `copyable`, a Copy
/// button appears on the row under the pointer (round 41.2, PO1).
struct FooterPopoverLine: View {
    let label: String
    let value: String
    var copyable = false

    @State private var isHovered = false
    @State private var didCopy = false

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            Text(label)
                .foregroundStyle(ColorTokens.Text.secondary)
            Spacer(minLength: SpacingTokens.xs)
            Text(value)
                .monospacedDigit()
                .textSelection(.enabled)
                .lineLimit(1)
            if copyable {
                Button {
                    PlainTextPasteboard.copy(value)
                    didCopy = true
                } label: {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                        .foregroundStyle(didCopy ? ColorTokens.Status.success : ColorTokens.Text.secondary)
                }
                .buttonStyle(.borderless)
                .help("Copy \(label)")
                .opacity(isHovered || didCopy ? 1 : 0)
            }
        }
        .font(TypographyTokens.standard)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

/// Puts text on the general pasteboard.
enum PlainTextPasteboard {
    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
