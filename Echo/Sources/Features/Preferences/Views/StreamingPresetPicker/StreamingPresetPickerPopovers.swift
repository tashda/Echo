import SwiftUI
#if os(macOS)
import AppKit
private typealias StreamingPopoverFont = NSFont
#elseif canImport(UIKit)
import UIKit
private typealias StreamingPopoverFont = UIFont
#endif

extension StreamingPresetPickerControl {
    struct CustomValuePopover: View {
        let title: String
        @Binding var text: String
        let rangeDescription: String
        let onSubmit: () -> Void
        let onCancel: () -> Void
        @FocusState private var fieldFocused: Bool

        var body: some View {
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                Text("Custom \(title)")
                    .font(TypographyTokens.headline)

                TextField("Value", text: $text, prompt: Text("1000"))
                    .textFieldStyle(.roundedBorder)
#if os(iOS)
                    .keyboardType(.numberPad)
#endif
                    .focused($fieldFocused)

                Text("Allowed range: \(rangeDescription)")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(ColorTokens.Text.secondary)

                HStack {
                    Spacer()
                    Button("Cancel", role: .cancel, action: onCancel)
                    Button("Done", action: onSubmit)
                        .buttonStyle(.bordered)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(SpacingTokens.md)
            .frame(width: 240)
            .onAppear {
                Task {
                    fieldFocused = true
                }
            }
        }
    }

    struct InfoPopover: View {
        let description: String
        let defaultLabel: String

        var body: some View {
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                Text(description)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                Text("Default: \(defaultLabel)")
                    .font(TypographyTokens.caption2)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(SpacingTokens.md)
            .frame(width: preferredWidth)
        }

        private var preferredWidth: CGFloat {
            let padding: CGFloat = 32
            let minWidth: CGFloat = 220
            let maxWidth: CGFloat = 320
            let contentLimit = maxWidth - padding

            let descriptionWidth = measuredWidth(for: description, font: platformFont(size: 13), limit: contentLimit)
            let defaultWidth = measuredWidth(for: "Default: \(defaultLabel)", font: platformFont(size: 12), limit: contentLimit)
            let contentWidth = max(descriptionWidth, defaultWidth)
            return min(maxWidth, max(minWidth, contentWidth + padding))
        }

        private func platformFont(size: CGFloat, weight: StreamingPopoverFont.Weight = .regular) -> StreamingPopoverFont {
#if os(macOS)
            NSFont.systemFont(ofSize: size, weight: weight)
#else
            UIFont.systemFont(ofSize: size, weight: weight)
#endif
        }

        private func measuredWidth(for text: String, font: StreamingPopoverFont, limit: CGFloat) -> CGFloat {
            guard !text.isEmpty else { return 0 }
            let constraint = CGSize(width: limit, height: .greatestFiniteMagnitude)
#if os(macOS)
            let rect = NSAttributedString(string: text, attributes: [.font: font])
                .boundingRect(with: constraint, options: [.usesLineFragmentOrigin, .usesFontLeading])
#else
            let rect = (text as NSString).boundingRect(with: constraint, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font], context: nil)
#endif
            return ceil(rect.width)
        }
    }
}
