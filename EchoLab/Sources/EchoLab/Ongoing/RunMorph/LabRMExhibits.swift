import SwiftUI

/// Echo's toolbar with Run in its own group, beside the capsule it must not push.
struct LabRMToolbarExhibit: View {
    let options: LabRMOptions
    let values: RoundValues

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let width: CGFloat = 640
    static let height: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            HStack(spacing: SpacingTokens.xs) {
                RunSpecimenCapsule { RunSpecimenGlyph(symbol: "sidebar.left") }
                Spacer(minLength: SpacingTokens.none)
                LabRMButton(options: options)
                RunSpecimenCapsule {
                    ForEach(["sparkles", "exclamationmark.triangle", "text.book.closed", "flowchart"], id: \.self) {
                        RunSpecimenGlyph(symbol: $0)
                    }
                }
                RunSpecimenCapsule {
                    ForEach(["square.grid.2x2", "arrow.clockwise", "bell", "sidebar.right"], id: \.self) {
                        RunSpecimenGlyph(symbol: $0)
                    }
                }
            }
            Text("select * from employees.employee;")
                .font(TypographyTokens.code)
                .padding(SpacingTokens.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .workspaceCard()
        }
        .padding(SpacingTokens.md)
        .background(ColorTokens.Workspace.canvas)
        .environment(\.echoMotion, LabRBPages.motion(values, reduceMotion: reduceMotion))
    }
}

/// The proposal's Run four times its size and four times slower; for the shape morphs a scrubber
/// steps through ▶ to ■ by hand.
struct LabRMSlowMotionExhibit: View {
    let options: LabRMOptions

    @State private var scrub = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let width: CGFloat = 520
    static let height: CGFloat = 360
    private static let magnification: CGFloat = 4

    var body: some View {
        VStack(spacing: SpacingTokens.lg) {
            LabRMButton(options: options)
                .scaleEffect(Self.magnification)
                .frame(height: RunSpecimenGlyph.size * Self.magnification)
                .environment(\.echoMotion, EchoMotion(durationScale: Self.magnification, reduceMotion: reduceMotion))
            if options.morph.isShape {
                Divider()
                HStack(spacing: SpacingTokens.lg) {
                    LabRMGlyph(morph: options.morph, isStop: false, colour: ColorTokens.Text.primary, scrub: scrub)
                        .scaleEffect(Self.magnification)
                        .frame(width: RunSpecimenGlyph.size * Self.magnification, height: RunSpecimenGlyph.size * Self.magnification)
                    Slider(value: $scrub, in: 0...1) { Text("▶ to ■") }
                        .frame(maxWidth: .infinity)
                }
            } else {
                Text("Symbol effects play at their own speed; the scrubber is for the shape morphs (M2, M3).")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
        .padding(SpacingTokens.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.Workspace.canvas)
    }
}

/// Every choice of one control at once, each a live Run with the rest of the proposal.
struct LabRMGalleryExhibit: View {
    let rows: [(name: String, options: LabRMOptions, isCurrent: Bool)]
    let values: RoundValues

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let width: CGFloat = 640
    static let height: CGFloat = 340
    private static let labelWidth: CGFloat = 250

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            ForEach(rows, id: \.name) { row in
                HStack(spacing: SpacingTokens.sm) {
                    Text(row.name)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(row.isCurrent ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
                        .frame(width: Self.labelWidth, alignment: .leading)
                    LabRMButton(options: row.options)
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
            Spacer(minLength: SpacingTokens.none)
        }
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ColorTokens.Workspace.canvas)
        .environment(\.echoMotion, LabRBPages.motion(values, reduceMotion: reduceMotion))
    }
}

/// What the gallery lines up.
enum LabRMCompare: String, CaseIterable {
    case morph = "Morphs"
    case fill = "Red fills"
    case grow = "Growing for the time"
    case curve = "Curves"
    case ending = "Endings"

    func rows(_ base: LabRMOptions) -> [(name: String, options: LabRMOptions, isCurrent: Bool)] {
        switch self {
        case .morph: Self.rows(\.morph, base)
        case .fill: Self.rows(\.fill, base)
        case .grow: Self.rows(\.grow, base)
        case .curve: Self.rows(\.curve, base)
        case .ending: Self.rows(\.ending, base)
        }
    }

    private static func rows<Choice: CaseIterable & RawRepresentable & Equatable>(
        _ path: WritableKeyPath<LabRMOptions, Choice>, _ base: LabRMOptions
    ) -> [(name: String, options: LabRMOptions, isCurrent: Bool)] where Choice.RawValue == String {
        Choice.allCases.map { ($0.rawValue, base.with(path, $0), base[keyPath: path] == $0) }
    }
}
