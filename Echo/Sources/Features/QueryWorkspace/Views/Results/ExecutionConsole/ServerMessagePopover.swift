import SwiftUI

/// What the server actually returned for a message (owner, after round 41.4): its number, level,
/// state, line, procedure and server, any other fields the driver passed on, and the text as sent,
/// selectable, with Copy. Opens from the message's symbol.
struct ServerMessagePopover: View {
    let message: QueryExecutionMessage

    @State private var didCopy = false

    var body: some View {
        FooterPopoverContent(title: "From the server", width: LayoutTokens.FloatingSurface.mediumWidth) {
            Button(didCopy ? "Copied" : "Copy") {
                PlainTextPasteboard.copy(message.serverCopyText)
                didCopy = true
            }
            .controlSize(.small)
        } content: {
            ForEach(message.serverFields, id: \.label) { field in
                FooterPopoverLine(label: field.label, value: field.value)
            }
            Divider()
            Text(message.message)
                .font(TypographyTokens.standard)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
