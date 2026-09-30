import SwiftUI

/// Round 10's lab questions: the footer's right-hand side and the database switcher.
struct LabRound10Playground: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            stage { LabFooterStage() }
            stage { LabSwitcherStage() }
        }
    }

    private func stage(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .background(Color(nsColor: .textBackgroundColor), in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.separator, lineWidth: 0.5))
            .fixedSize()
    }
}
