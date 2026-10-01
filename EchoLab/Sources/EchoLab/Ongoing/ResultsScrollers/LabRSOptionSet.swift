import CoreGraphics

/// Round 27: every option the proposal is built from.
struct LabRSOptionSet {
    var placement: LabRSPlacement
    var style: LabRSBarStyle
    var visibility: LabRSVisibility
    var vertical: LabRSVertical
    var extra: LabRSExtra

    /// Echo before round 27: the bar floating a footer above the footer.
    static let before = LabRSOptionSet(placement: .aboveFooter, style: .system, visibility: .whileScrolling,
                                       vertical: .aboveFooter, extra: .none)
    /// Round 27 as accepted and built: E, S1, V1, R2, X1.
    static let decided = LabRSOptionSet(placement: .footerEdge, style: .system, visibility: .whileScrolling,
                                        vertical: .toBottom, extra: .edgeFades)

    /// The bars' lane.
    var lane: CGFloat { style.lane }
    var footerLift: CGFloat { placement.extraFooterLift(lane: lane) }
    var footerZone: CGFloat { LayoutTokens.Footer.height + LayoutTokens.Footer.bottomLift + footerLift }

    func horizontalFrame(cornerRadius: CGFloat, chips: (left: CGFloat, right: CGFloat)) -> LabRSBarFrame? {
        placement.horizontalFrame(footerZone: footerZone, cornerRadius: cornerRadius, chips: chips, lane: lane)
    }

    /// Where the vertical bar ends above the card's bottom edge; nil when there is none.
    func verticalBottom(cornerRadius: CGFloat, chips: (left: CGFloat, right: CGFloat)) -> CGFloat? {
        switch vertical {
        case .hidden: nil
        // Echo today ends it where it puts the horizontal bar, a footer higher.
        case .aboveFooter: placement == .aboveFooter ? footerZone * 2 : footerZone
        case .toBottom:
            horizontalFrame(cornerRadius: cornerRadius, chips: chips).map { $0.bottom + lane } ?? cornerRadius
        }
    }
}
