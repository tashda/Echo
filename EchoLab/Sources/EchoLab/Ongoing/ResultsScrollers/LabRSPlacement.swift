import AppKit

/// Round 27: where the results grid's horizontal scroll bar sits.
enum LabRSPlacement: String, CaseIterable {
    case aboveFooter = "A · Above the footer"
    case bottomEdge = "B · Along the bottom edge"
    case inFooter = "C · Inside the footer"

    var summary: String {
        switch self {
        case .aboveFooter: "Echo today: the bar floats over the last rows, just above the footer, and the vertical bar stops there too."
        case .bottomEdge: "The bar runs along the card's bottom edge, in the lane under the footer's chips, inside the rounded corners. The vertical bar runs down to meet it."
        case .inFooter: "The bar sits inside the footer, between the connection chip and the pills, as part of the footer bar."
        }
    }

    /// The scroll view's scroller insets for this placement. `footerZone` is the footer's height
    /// plus its lift; `chips` is the room the footer's left chip and right pills take.
    func scrollerInsets(footerZone: CGFloat, cornerRadius: CGFloat, chips: (left: CGFloat, right: CGFloat)) -> NSEdgeInsets {
        switch self {
        case .aboveFooter:
            // As Echo sets it (ResultTableContainerView.setFooterOverlay).
            NSEdgeInsets(top: 0, left: 0, bottom: footerZone, right: 0)
        case .bottomEdge:
            NSEdgeInsets(top: 0, left: cornerRadius, bottom: 0, right: cornerRadius)
        case .inFooter:
            NSEdgeInsets(top: 0, left: chips.left, bottom: footerZone / 2 - Self.overlayThickness / 2, right: chips.right)
        }
    }

    /// An overlay scroller's lane.
    static var overlayThickness: CGFloat {
        NSScroller.scrollerWidth(for: .regular, scrollerStyle: .overlay)
    }
}

/// Wider than the card, so the horizontal bar has something to scroll.
enum LabRSColumns: String, CaseIterable {
    case twelve = "12 columns"
    case forty = "40 columns"

    var count: Int { self == .twelve ? 12 : 40 }
}
