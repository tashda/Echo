import SwiftUI

/// The title banner's name row with the section at its right (round 58, LY2): the name on the
/// left, the section's label on the right, one row. The label keeps its own width up to
/// `ServerHeaderMetrics.rightLabelShare` of the row and the name gives way (it truncates), so
/// the two never overlap. The row is the room left of the chevron's reserved slot, so the label
/// never meets the chevron.
struct ServerHeaderNameRowLayout: Layout {
    /// The least room kept between the name and the label.
    let gap: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let name = subviews[0].sizeThatFits(.unspecified)
        let label = subviews[1].sizeThatFits(.unspecified)
        return CGSize(width: proposal.width ?? name.width + gap + label.width, height: max(name.height, label.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let labelIdeal = subviews[1].sizeThatFits(.unspecified).width
        let labelWidth = min(labelIdeal, bounds.width * ServerHeaderMetrics.rightLabelShare)
        let nameWidth = max(0, min(subviews[0].sizeThatFits(.unspecified).width, bounds.width - labelWidth - gap))
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading,
                          proposal: ProposedViewSize(width: nameWidth, height: bounds.height))
        subviews[1].place(at: CGPoint(x: bounds.maxX, y: bounds.midY), anchor: .trailing,
                          proposal: ProposedViewSize(width: labelWidth, height: bounds.height))
    }
}
