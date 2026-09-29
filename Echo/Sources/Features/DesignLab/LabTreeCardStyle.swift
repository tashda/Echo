#if DEBUG
import SwiftUI

// Tree card page: the styles and the shared controls. A style only changes what's inside the
// server card; the card itself is the real `.workspaceCard()`.

enum LabTreeCardStyle: String, CaseIterable, Identifiable {
    case today = "Original"
    case tahoe = "S1 Tahoe"
    case tiles = "S2 Tiles"
    case structure = "S3 Structure"
    case quiet = "S4 Quiet"
    case detailed = "S5 Detailed"
    case path = "S6 Path"
    var id: String { rawValue }

    var isReference: Bool { self == .today }
    var code: String { isReference ? "Original" : String(rawValue.prefix(2)) }

    var summary: String {
        switch self {
        case .today: "The original tree: 11pt grey server name, outline symbols, 10pt chevrons, grey selection, schema prefix on every table."
        case .tahoe: "Finder on macOS 26, refined: hierarchical symbols, lighter 9pt chevrons, 26pt rows, accent-tinted selection, bold 13pt server name with its version."
        case .tiles: "System Settings: every folder gets a small coloured tile with a white glyph, objects keep plain glyphs, counts in soft capsules, a monogram header."
        case .structure: "Xcode and DataGrip: compact 22pt rows with thin indent guides; the guide of the selected branch turns accent, selection is solid accent."
        case .quiet: "Linear and Notion: no chevron column. A folder's icon turns into its chevron on hover, counts appear on hover, light symbols, roomy 28pt rows."
        case .detailed: "Postico and TablePlus: databases get a second line (tables, size), tables show row counts, filled gradient symbols, counts in capsules."
        case .path: "Arc and Things: the path to the selection lights up (accent icons, medium labels, one accent guide), selection is a bar plus a tint."
        }
    }

    var spec: LabTreeSpec {
        switch self {
        case .today:
            LabTreeSpec(rowHeight: 24, labelSize: 13, iconSize: 14, iconFrame: 18, iconGap: 6, indent: 12, chevron: .leading(size: 10, weight: .semibold, strength: .tertiary), icon: .outline, count: .plain, selection: .grey, header: .today, corner: 7, rowGap: 0)
        case .tahoe:
            LabTreeSpec(rowHeight: 26, labelSize: 13, iconSize: 13, iconFrame: 18, iconGap: 7, indent: 14, chevron: .leading(size: 9, weight: .bold, strength: .quaternary), icon: .hierarchical, count: .plain, selection: .accentTint, header: .boldWithVersion, corner: 8, rowGap: 1)
        case .tiles:
            LabTreeSpec(rowHeight: 28, labelSize: 13, iconSize: 12, iconFrame: 20, iconGap: 8, indent: 14, chevron: .leading(size: 9, weight: .semibold, strength: .tertiary), icon: .tiles, count: .capsule, selection: .grey, header: .monogram, corner: 8, rowGap: 1)
        case .structure:
            LabTreeSpec(rowHeight: 22, labelSize: 12, iconSize: 12, iconFrame: 16, iconGap: 5, indent: 14, chevron: .leading(size: 8, weight: .bold, strength: .tertiary), icon: .filled, count: .plain, selection: .accentSolid, header: .compact, corner: 5, rowGap: 0, guides: .all)
        case .quiet:
            LabTreeSpec(rowHeight: 28, labelSize: 13, iconSize: 13, iconFrame: 18, iconGap: 8, indent: 16, chevron: .replacesIcon, icon: .light, count: .onHover, selection: .grey, header: .boldWithVersion, corner: 8, rowGap: 1)
        case .detailed:
            LabTreeSpec(rowHeight: 26, labelSize: 13, iconSize: 13, iconFrame: 18, iconGap: 7, indent: 14, chevron: .leading(size: 9, weight: .semibold, strength: .tertiary), icon: .gradient, count: .capsule, selection: .accentTint, header: .monogram, corner: 8, rowGap: 1, showsMetrics: true)
        case .path:
            LabTreeSpec(rowHeight: 26, labelSize: 13, iconSize: 13, iconFrame: 18, iconGap: 7, indent: 14, chevron: .leading(size: 9, weight: .semibold, strength: .tertiary), icon: .hierarchical, count: .plain, selection: .accentBar, header: .dot, corner: 7, rowGap: 1, guides: .selectedBranch, highlightsPath: true)
        }
    }
}

/// Every measurement and treatment a style controls.
struct LabTreeSpec {
    enum Strength { case tertiary, quaternary }
    enum Chevron {
        case leading(size: CGFloat, weight: Font.Weight, strength: Strength)
        /// No chevron column: a folder's icon becomes its chevron on hover.
        case replacesIcon
    }
    enum Icon { case outline, light, hierarchical, filled, gradient, tiles }
    enum Count { case plain, capsule, onHover }
    enum Selection { case grey, accentTint, accentSolid, accentBar }
    enum Header { case today, boldWithVersion, monogram, compact, dot }
    enum Guides { case none, all, selectedBranch }

    var rowHeight: CGFloat
    var labelSize: CGFloat
    var iconSize: CGFloat
    var iconFrame: CGFloat
    var iconGap: CGFloat
    var indent: CGFloat
    var chevron: Chevron
    var icon: Icon
    var count: Count
    var selection: Selection
    var header: Header
    var corner: CGFloat
    var rowGap: CGFloat
    var guides: Guides = .none
    var showsMetrics = false
    var highlightsPath = false

    var chevronWidth: CGFloat {
        if case .replacesIcon = chevron { return 0 }
        return 12
    }
    var outerPadding: CGFloat { 6 }
    var innerPadding: CGFloat { 6 }
}

// MARK: - Shared controls

enum LabTreeIconMode: String, CaseIterable, Identifiable {
    case colorful = "Colourful"
    case monochrome = "Monochrome"
    var id: String { rawValue }
}

enum LabTreePalette: String, CaseIterable, Identifiable {
    case vivid = "Vivid"
    case soft = "Soft"
    case families = "Families"
    case server = "Server colour"
    var id: String { rawValue }

    func color(for role: LabNodeRole, serverColor: Color) -> Color {
        let grey = ColorTokens.Text.secondary
        switch self {
        case .vivid: return role.vividColor.mix(with: grey, by: ColorTokens.Explorer.colorfulSoftening)
        case .soft: return role.vividColor.mix(with: grey, by: 0.5)
        case .families: return role.familyColor.mix(with: grey, by: 0.15)
        case .server: return serverColor.mix(with: grey, by: 0.15)
        }
    }
}

enum LabTreeSchemaMode: String, CaseIterable, Identifiable {
    case prefix = "Dimmed prefix"
    case trailing = "Name, schema right"
    case groups = "Schema groups"
    var id: String { rawValue }
}

enum LabTreeTopLevel: String, CaseIterable, Identifiable {
    case folders = "Folders"
    case sections = "Sections"
    var id: String { rawValue }
}

/// The controls that apply to every style at once.
struct LabTreeLook {
    var icons: LabTreeIconMode = .colorful
    var palette: LabTreePalette = .vivid
    var schema: LabTreeSchemaMode = .prefix
    var topLevel: LabTreeTopLevel = .folders
}
#endif
