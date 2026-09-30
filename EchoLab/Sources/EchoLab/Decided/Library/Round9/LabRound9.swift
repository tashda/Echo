import SwiftUI

/// Round 9's open questions, judged live (Design/decisions.md, round 9): the footer's position
/// and what shows behind it, the tree's scroll bar, and the tab bar.
struct LabRound9Playground: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            stage { LabFooterStage() }
            stage { LabScrollerStage() }
            stage { LabTabsStage() }
        }
    }

    private func stage(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .background(Color(nsColor: .textBackgroundColor), in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.separator, lineWidth: 0.5))
            .fixedSize()
    }
}
