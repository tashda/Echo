import SwiftUI

/// Reusable row for selecting a streaming execution mode (Auto / Simple / Cursor)
/// with a segmented picker and info popover. Used in per-engine settings tabs.
struct DatabaseStreamingModeRow: View {
    @Binding var selection: ResultStreamingExecutionMode
    @State private var isPopoverPresented = false

    private static let modeDescriptions: [(mode: ResultStreamingExecutionMode, summary: String)] = [
        (.auto, "Picks the best strategy per query"),
        (.simple, "Fetches all rows in one pass"),
        (.cursor, "Server-side cursor for large results"),
    ]

    var body: some View {
        LabeledContent {
            HStack(spacing: SpacingTokens.xxs2) {
                Picker("", selection: $selection) {
                    ForEach(ResultStreamingExecutionMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)

                Button(action: { isPopoverPresented.toggle() }) {
                    Image(systemName: "info.circle")
                        .imageScale(.medium)
                }
                .buttonStyle(.plain)
                .foregroundStyle(ColorTokens.Text.secondary)
                .popover(
                    isPresented: $isPopoverPresented,
                    attachmentAnchor: .rect(.bounds),
                    arrowEdge: .trailing
                ) {
                    VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                        ForEach(Self.modeDescriptions, id: \.mode) { item in
                            HStack(alignment: .top, spacing: SpacingTokens.xs) {
                                Text(item.mode.displayName)
                                    .font(TypographyTokens.standard.weight(.semibold))
                                    .frame(width: 56, alignment: .leading)
                                Text(item.summary)
                                    .font(TypographyTokens.standard)
                                    .foregroundStyle(ColorTokens.Text.secondary)
                            }
                        }
                    }
                    .padding(SpacingTokens.md)
                    .frame(width: 320)
                }
            }
        } label: {
            Text("Streaming Mode")
        }
    }
}
