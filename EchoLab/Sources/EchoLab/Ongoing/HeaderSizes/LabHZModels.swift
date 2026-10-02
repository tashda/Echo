import SwiftUI

/// Round 58. The title banner is too big even at Small. Smaller names, tighter spacing, and layouts
/// that need fewer lines; and every setting's effect on the header's height written down and
/// drawn from the same numbers (`LabHZMetrics`), so Line Above the Name = None is only the name
/// and tight.
enum LabHZLayout: String, CaseIterable {
    case stacked = "LY0 · Stacked: line, name, icon menu (as built)"
    case inline = "LY1 · One row: the name on the left, the icon menu on the right"
    case twoRows = "LY2 · The line at the right of the name's row, the icon menu below"
    case slim = "LY3 · A slim banner with the name, the icon menu below on the card"
    case compactMenu = "LY4 · The name above a compact icon menu (smaller icons, shorter row)"

    var summary: String {
        switch self {
        case .stacked: "The line over the name over the icon menu: three rows."
        case .inline: "The name and the five icons share one row: the shortest banner. The name gets what the icons leave of the card's width."
        case .twoRows: "The line (DATABASES) moves to the right end of the name's row, small; the icon menu is the second row."
        case .slim: "A 30pt banner with the name only; the icon menu sits under it on the plain card in the server's colour."
        case .compactMenu: "As stacked, with 13pt icons in a 24pt row."
        }
    }
}

enum LabHZSize: String, CaseIterable {
    case s12 = "NS0 · 12", s13 = "NS1 · 13", s14 = "NS2 · 14", s16 = "NS3 · 16", s18 = "NS4 · 18 (today's Small)", s22 = "NS5 · 22 (today's Medium)"

    var points: CGFloat {
        switch self {
        case .s12: 12
        case .s13: 13
        case .s14: 14
        case .s16: 16
        case .s18: 18
        case .s22: 22
        }
    }
}

enum LabHZEyebrow: String, CaseIterable {
    case section = "EB0 · The section"
    case engine = "EB1 · The engine"
    case none = "EB2 · None: only the name"
}

enum LabHZDensity: String, CaseIterable {
    case tight = "DN0 · Tight"
    case standard = "DN1 · Standard"

    var pad: CGFloat { self == .tight ? 6 : 10 }
}

struct LabHZLook {
    var layout = LabHZLayout.stacked
    var size = LabHZSize.s16
    var eyebrow = LabHZEyebrow.section
    var density = LabHZDensity.tight

    static let today = LabHZLook(layout: .stacked, size: .s22, eyebrow: .section, density: .standard)

    @MainActor init(_ values: RoundValues) {
        layout = LabHZLayout(rawValue: values["layout"]) ?? .stacked
        size = LabHZSize(rawValue: values["size"]) ?? .s16
        eyebrow = LabHZEyebrow(rawValue: values["eyebrow"]) ?? .section
        density = LabHZDensity(rawValue: values["density"]) ?? .tight
    }

    init(layout: LabHZLayout, size: LabHZSize, eyebrow: LabHZEyebrow, density: LabHZDensity) {
        self.layout = layout; self.size = size; self.eyebrow = eyebrow; self.density = density
    }
}

/// The header's heights, from one set of numbers: the drawing uses them and the table shows them.
enum LabHZMetrics {
    static let eyebrowPoints: CGFloat = 10
    static let dockRow: CGFloat = 28
    static let compactDockRow: CGFloat = 24
    static let slimBanner: CGFloat = 30
    static let gap: CGFloat = 3

    static func nameHeight(_ look: LabHZLook) -> CGFloat { (look.size.points * 1.2).rounded() }
    static func eyebrowHeight(_ look: LabHZLook) -> CGFloat { look.eyebrow == .none ? 0 : (eyebrowPoints * 1.2).rounded() }

    /// The banner's height (the part in colour), and the whole header including the icon menu where it is outside the banner.
    static func banner(_ look: LabHZLook) -> CGFloat {
        let pad = look.density.pad
        switch look.layout {
        case .stacked:
            return pad + eyebrowHeight(look) + (look.eyebrow == .none ? 0 : gap) + nameHeight(look) + gap + dockRow + pad
        case .compactMenu:
            return pad + eyebrowHeight(look) + (look.eyebrow == .none ? 0 : gap) + nameHeight(look) + gap + compactDockRow + pad
        case .inline:
            return pad + max(nameHeight(look), dockRow) + pad
        case .twoRows:
            return pad + max(nameHeight(look), eyebrowHeight(look)) + gap + dockRow + pad
        case .slim:
            return slimBanner
        }
    }

    static func total(_ look: LabHZLook) -> CGFloat {
        look.layout == .slim ? slimBanner + gap + dockRow : banner(look)
    }
}
