import SwiftUI

/// A Properties tool's changes, applied together (round 37.4, PR0): a bar at the bottom of its
/// card with how many changes wait, Revert and the prominent Apply. It shows only while there are
/// changes.
struct ToolTabApplyBar: View {
    /// "2 changes", "Unsaved changes".
    let summary: String
    var applyTitle = "Apply"
    var canApply = true
    var isApplying = false
    /// An extra action before Revert, such as Script.
    var extraTitle: String?
    var onExtra: (() -> Void)?
    let onRevert: () -> Void
    let onApply: () -> Void

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            Text(summary)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
            Spacer(minLength: SpacingTokens.sm)
            if isApplying {
                ProgressView().controlSize(.small)
            }
            if let extraTitle, let onExtra {
                Button(extraTitle, action: onExtra)
                    .disabled(isApplying)
            }
            Button("Revert", action: onRevert)
                .disabled(isApplying)
            Button(applyTitle, action: onApply)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canApply || isApplying)
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xs)
        .background(alignment: .top) { Divider() }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    /// "1 change", "3 changes".
    static func summary(count: Int) -> String {
        count == 1 ? "1 change" : "\(count) changes"
    }
}
