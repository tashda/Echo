import SwiftUI

/// A small badge for marking features as Beta, Preview, or other status labels.
/// Used to indicate implementation maturity across the app.
struct FeatureBadge: View {
    let label: String
    var tint: Color = .orange

    var body: some View {
        Text(label)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(tint.opacity(0.12), in: Capsule())
    }

    static var beta: FeatureBadge {
        FeatureBadge(label: "BETA", tint: .orange)
    }

    static var preview: FeatureBadge {
        FeatureBadge(label: "PREVIEW", tint: .purple)
    }
}
