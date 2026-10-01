import EchoSense
import SwiftUI

/// The selection pill's popover (round 41.2, PO1 and FG1): the exact figures, each with a Copy
/// button on the row under the pointer, and Copy All.
struct SelectionSummaryPopover: View {
    let summary: GridSelectionSummary

    @State private var didCopyAll = false

    private var title: String {
        guard let column = summary.columnName else { return summary.text }
        return "\(summary.text) in \(column)"
    }

    var body: some View {
        FooterPopoverContent(title: title) {
            Button(didCopyAll ? "Copied" : "Copy All") {
                PlainTextPasteboard.copy(summary.copyAllText())
                didCopyAll = true
            }
            .controlSize(.small)
        } content: {
            ForEach(summary.figures()) { figure in
                FooterPopoverLine(label: figure.label, value: figure.value, copyable: true)
            }
            if !summary.isComplete {
                Text("More than \(GridSelectionSummary.maximumSummedCells.formatted()) cells: only counted.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
        }
    }
}
