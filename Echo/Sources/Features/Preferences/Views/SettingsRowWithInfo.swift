import SwiftUI

/// A reusable settings row that displays a label with an info popover button,
/// and a trailing control. Used throughout settings to provide contextual help
/// without inline description text.
struct SettingsRowWithInfo<Control: View>: View {
    let title: String
    let description: String
    @ViewBuilder let control: () -> Control
    @State private var showPopover = false

    var body: some View {
        LabeledContent {
            HStack(spacing: SpacingTokens.xxs2) {
                control()
                infoButton
            }
        } label: {
            Text(title)
        }
    }

    private var infoButton: some View {
        Button(action: { showPopover.toggle() }) {
            Image(systemName: "info.circle")
                .imageScale(.medium)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .popover(isPresented: $showPopover, attachmentAnchor: .rect(.bounds), arrowEdge: .trailing) {
            Text(description)
                .font(TypographyTokens.standard)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(SpacingTokens.md)
                .frame(width: 280)
        }
    }
}
