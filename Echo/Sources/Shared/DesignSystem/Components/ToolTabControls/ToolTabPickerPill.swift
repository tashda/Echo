import SwiftUI

/// A tool tab's picker (round 37.3, PK1): one 28pt glass pill with a symbol, the value and a
/// chevron, opening a menu of the choices.
struct ToolTabPickerPill<Value: Hashable>: View {
    let title: String
    let systemImage: String
    @Binding var selection: Value
    let options: [Value]
    let label: (Value) -> String

    var body: some View {
        Menu {
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(label(option)).tag(option)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            HStack(spacing: SpacingTokens.xxs2) {
                Image(systemName: systemImage)
                    .foregroundStyle(ColorTokens.Text.secondary)
                Text(label(selection))
                    .foregroundStyle(ColorTokens.Text.primary)
                Image(systemName: "chevron.down")
                    .font(TypographyTokens.compact.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .font(TypographyTokens.standard)
            .lineLimit(1)
            .padding(.horizontal, SpacingTokens.sm)
            .frame(height: LayoutTokens.ToolTab.controlHeight)
            .contentShape(.capsule)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .glassEffect(.regular.interactive(), in: .capsule)
        .help(title)
        .accessibilityLabel("\(title): \(label(selection))")
    }
}
