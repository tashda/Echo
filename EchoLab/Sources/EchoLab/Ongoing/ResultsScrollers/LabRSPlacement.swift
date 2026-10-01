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
        case .aboveFooter: "Echo today: the bar floats over the rows a footer's height above the footer (Echo adds the footer's room twice), and the vertical bar stops there too."
        case .bottomEdge: "The bar runs along the card's bottom edge, in the lane under the footer's chips, inside the rounded corners. The vertical bar runs down to meet it."
        case .inFooter: "The bar sits inside the footer, between the connection chip and the pills, as part of the footer bar."
        case .ownLane: "The footer is lifted by one bar's height, and the bar gets a lane of its own along the bottom edge, so it never meets a chip, even when it widens under the pointer."
        case .footerEdge: "The bar sits on the line where the footer's blur begins, half over the blur, so it reads as the footer's top edge rather than a bar over the rows."
        case .glassTrack: "No system bar: a glass capsule in the footer, the height of its chips, shows how much of the width you see and where; drag the thumb to scroll."
        case .positionChip: "No bar at all: a glass chip says which columns you are looking at (Columns 9–16 of 40). Scroll sideways with the trackpad or Shift and the wheel."
        }
    }

    /// Where the horizontal bar sits: its distance from the card's bottom edge and its ends' insets.
    /// Nil when the placement has no bar (F and G). `lane` is the bar's height.
    func horizontalFrame(footerZone: CGFloat, cornerRadius: CGFloat, chips: (left: CGFloat, right: CGFloat),
                         lane: CGFloat) -> LabRSBarFrame? {
        switch self {
        case .aboveFooter:
            // Echo adds the footer's room twice (content inset and scroller inset), measured 2026-10-01.
            LabRSBarFrame(bottom: footerZone * 2, left: 0, right: 0)
        case .bottomEdge:
            LabRSBarFrame(bottom: 0, left: cornerRadius, right: cornerRadius)
        case .inFooter:
            LabRSBarFrame(bottom: LayoutTokens.Footer.bottomLift + (LayoutTokens.Footer.height - lane) / 2,
                          left: chips.left, right: chips.right)
        case .ownLane:
            LabRSBarFrame(bottom: 0, left: cornerRadius, right: cornerRadius)
        case .footerEdge:
            // Decided with the owner's note: the thumb as far above the pills as the pills sit
            // above the card's edge (LayoutTokens.Footer.scrollBarBottom); the thumb is centred in its lane.
            LabRSBarFrame(bottom: LayoutTokens.Footer.scrollBarBottom - (lane - LabRSBarStyle.system.thickness) / 2,
                          left: SpacingTokens.sm, right: SpacingTokens.sm)
        case .glassTrack, .positionChip:
            nil
        }
    }

    /// How much higher the footer sits than Echo's 4pt lift: D gives the bar a lane of its own.
    func extraFooterLift(lane: CGFloat) -> CGFloat { self == .ownLane ? lane : 0 }

    /// The footer's gap between its chips is taken by the bar (C), the track (F) or the chip (G).
    var takesFooterGap: Bool { self == .inFooter || self == .glassTrack || self == .positionChip }

    /// An overlay scroller's lane.
    static var overlayThickness: CGFloat {
        NSScroller.scrollerWidth(for: .regular, scrollerStyle: .overlay)
    }
}

/// A bar's place: distance from the card's bottom edge, and how far its ends are inset.
struct LabRSBarFrame: Equatable {
    var bottom: CGFloat
    var left: CGFloat
    var right: CGFloat
}

/// Wider than the card, so the horizontal bar has something to scroll.
enum LabRSColumns: String, CaseIterable {
    case twelve = "12 columns"
    case forty = "40 columns"

    var count: Int { self == .twelve ? 12 : 40 }
}
