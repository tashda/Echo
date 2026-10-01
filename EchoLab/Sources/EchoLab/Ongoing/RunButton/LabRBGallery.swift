import SwiftUI

/// One row of a side-by-side gallery: a choice's name and the whole proposal with that choice.
struct LabRBGalleryRow: Identifiable {
    let id: String
    let look: LabRBLook
    let isCurrent: Bool

    static func rows<Choice: CaseIterable & RawRepresentable & Equatable>(
        _ path: WritableKeyPath<LabRBLook, Choice>, base: LabRBLook
    ) -> [LabRBGalleryRow] where Choice.RawValue == String {
        Choice.allCases.map { LabRBGalleryRow(id: $0.rawValue, look: base.with(path, $0), isCurrent: base[keyPath: path] == $0) }
    }
}

/// What page 1's gallery lines up.
enum LabRBCompareRest: String, CaseIterable {
    case form = "Forms"
    case icon = "Icons"
    case colour = "Colours"
    case selection = "Selection signals"
    case hover = "Hover"
    case unavailable = "When it can't run"
    case menu = "Other modes"
    case memory = "Last mode"

    func rows(_ base: LabRBLook) -> [LabRBGalleryRow] {
        switch self {
        case .form: LabRBGalleryRow.rows(\.form, base: base)
        case .icon: LabRBGalleryRow.rows(\.icon, base: base)
        case .colour: LabRBGalleryRow.rows(\.colour, base: base)
        case .selection: LabRBGalleryRow.rows(\.selection, base: base)
        case .hover: LabRBGalleryRow.rows(\.hover, base: base)
        case .unavailable: LabRBGalleryRow.rows(\.unavailable, base: base)
        case .menu: LabRBGalleryRow.rows(\.menu, base: base)
        case .memory: LabRBGalleryRow.rows(\.memory, base: base)
        }
    }
}

/// What page 2's gallery lines up.
enum LabRBCompareRunning: String, CaseIterable {
    case running = "Running looks"
    case delay = "Delays"
    case timer = "Timer formats"
    case stopIcon = "Stop icons"
    case motion = "Motion while running"
    case change = "Changes into running"
    case result = "Results"
    case hold = "Result holds"

    func rows(_ base: LabRBLook) -> [LabRBGalleryRow] {
        switch self {
        case .running: LabRBGalleryRow.rows(\.running, base: base)
        case .delay: LabRBGalleryRow.rows(\.delay, base: base)
        case .timer: LabRBGalleryRow.rows(\.timerFormat, base: base)
        case .stopIcon: LabRBGalleryRow.rows(\.stopIcon, base: base)
        case .motion: LabRBGalleryRow.rows(\.runningMotion, base: base)
        case .change: LabRBGalleryRow.rows(\.change, base: base)
        case .result: LabRBGalleryRow.rows(\.result, base: base)
        case .hold: LabRBGalleryRow.rows(\.hold, base: base)
        }
    }
}

/// Every choice of one control at once, each a live Run beside a neighbour capsule, all driven by
/// the same query. The proposal's current choice is highlighted.
struct LabRBGalleryExhibit: View {
    let rows: [LabRBGalleryRow]
    let values: RoundValues

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let width: CGFloat = 640
    static let height: CGFloat = 420
    static let labelWidth: CGFloat = 250

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                ForEach(rows) { row in
                    HStack(spacing: SpacingTokens.sm) {
                        Text(row.id)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(row.isCurrent ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
                            .frame(width: Self.labelWidth, alignment: .leading)
                        LabRBButton(style: row.look, editor: LabRBPages.editorState())
                        RunSpecimenCapsule {
                            ForEach(["sparkles", "exclamationmark.triangle"], id: \.self) { RunSpecimenGlyph(symbol: $0) }
                        }
                        Spacer(minLength: SpacingTokens.none)
                    }
                    .padding(.horizontal, SpacingTokens.xs)
                    .padding(.vertical, SpacingTokens.xxs)
                    .background(row.isCurrent ? ColorTokens.Surface.selected : .clear,
                                in: .rect(cornerRadius: ShapeTokens.CornerRadius.medium))
                }
            }
            .padding(SpacingTokens.md)
        }
        .labScrollSizing()
        .background(ColorTokens.Workspace.canvas)
        .environment(\.echoMotion, LabRBPages.motion(values, reduceMotion: reduceMotion))
    }
}

/// Every icon in every colour, still, in the proposal's form: a quick scan of the whole palette.
struct LabRBIconGridExhibit: View {
    let base: LabRBLook

    static let width: CGFloat = 640
    static let height: CGFloat = 400

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: SpacingTokens.sm, verticalSpacing: SpacingTokens.xs) {
            GridRow {
                Text("")
                ForEach(LabRBColour.allCases, id: \.self) { colour in
                    Text(colour.rawValue.components(separatedBy: " · ").first ?? "")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
            ForEach(LabRBIcon.allCases, id: \.self) { icon in
                GridRow {
                    Text(icon.rawValue.components(separatedBy: " · ").dropFirst().joined())
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                    ForEach(LabRBColour.allCases, id: \.self) { colour in
                        LabRBButton(style: base.with(\.icon, icon).with(\.colour, colour), isSample: true)
                            .overlay {
                                if icon == base.icon && colour == base.colour {
                                    Capsule().strokeBorder(ColorTokens.accent, lineWidth: SpacingTokens.micro)
                                }
                            }
                    }
                }
            }
        }
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ColorTokens.Workspace.canvas)
    }
}
