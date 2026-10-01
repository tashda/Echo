import AppKit

/// Round 27: where the results grid's horizontal scroll bar sits.
enum LabRSPlacement: String, CaseIterable {
    case aboveFooter = "A · Above the footer"
    case bottomEdge = "B · Along the bottom edge"
    case inFooter = "C · Inside the footer"
    case ownLane = "D · Its own lane under the footer"
    case footerEdge = "E · On the footer's top edge"
    case glassTrack = "F · A glass track in the footer"
    case positionChip = "G · No bar, a position chip"

    /// Added in revision 2, when the owner asked for more options.
    static let revision2: [LabRSPlacement] = [.ownLane, .footerEdge, .glassTrack, .positionChip]

    var summary: String {
        switch self {
        case .aboveFooter: "Echo today: the bar floats over the last rows, just above the footer, and the vertical bar stops there too."
        case .bottomEdge: "The bar runs along the card's bottom edge, in the lane under the footer's chips, inside the rounded corners. The vertical bar runs down to meet it."
        case .inFooter: "The bar sits inside the footer, between the connection chip and the pills, as part of the footer bar."
        case .ownLane: "The footer is lifted by one bar's height, and the bar gets a lane of its own along the bottom edge, so it never meets a chip, even when it widens under the pointer."
        case .footerEdge: "The bar sits on the line where the footer's blur begins, half over the blur, so it reads as the footer's top edge rather than a bar over the rows."
        case .glassTrack: "No system bar: a glass capsule in the footer, the height of its chips, shows how much of the width you see and where; drag the thumb to scroll."
        case .positionChip: "No bar at all: a glass chip says which columns you are looking at (Columns 9–16 of 40). Scroll sideways with the trackpad or Shift and the wheel."
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
        case .ownLane:
            NSEdgeInsets(top: 0, left: cornerRadius, bottom: 0, right: cornerRadius)
        case .footerEdge:
            NSEdgeInsets(top: 0, left: 0, bottom: footerZone - Self.overlayThickness / 2, right: 0)
        case .glassTrack, .positionChip:
            NSEdgeInsets(top: 0, left: 0, bottom: footerZone, right: 0)
        }
    }

    /// Whether the grid keeps the system's horizontal bar.
    var showsSystemBar: Bool { self != .glassTrack && self != .positionChip }

    /// How much higher the footer sits than Echo's 4pt lift.
    var extraFooterLift: CGFloat { self == .ownLane ? Self.overlayThickness : 0 }

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
