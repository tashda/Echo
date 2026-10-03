import SwiftUI

/// A small red chip for a real problem: a failed build, a conflict, a failed sync (DESIGN.md principle 6).
/// Amber means "your turn", so it must not stand in for a problem.
struct HXProblemChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .foregroundStyle(Theme.critical)
            .background(Theme.criticalBackground, in: Capsule())
    }
}
