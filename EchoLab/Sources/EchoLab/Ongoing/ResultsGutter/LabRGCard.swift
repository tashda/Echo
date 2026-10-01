import SwiftUI

/// What one results card in round 47 looks like, read from the round's controls.
@MainActor
struct LabRGLook {
    typealias R = ResultsGutterRound
    var style: R.Style
    var align: R.Align
    var width: R.Width
    var headers: R.Headers
    var corner: R.Corner
    var selected: R.Selected
    var cross: R.StripeCross
    var rows: R.RowsScene
    var selection: R.SelectionScene
    var stripes: Bool
    /// Echo today draws the system's line 4pt above the gutter's (the owner's screenshot).
    var doubledRule = false
    /// The one rounded shape of shaded rows, hover and selection, in the grid and the gutter, as Echo
    /// draws them since round 47 (Echo today is square in the gutter, and its hover was wider than its shade).
    var rounded = false

    private init(values: RoundValues, style: R.Style, align: R.Align, width: R.Width, headers: R.Headers, corner: R.Corner,
                 selected: R.Selected, cross: R.StripeCross, doubledRule: Bool) {
        self.style = style; self.align = align; self.width = width; self.headers = headers; self.corner = corner
        self.selected = selected; self.cross = cross; self.doubledRule = doubledRule
        rows = R.RowsScene(rawValue: values["rows"]) ?? .few
        selection = R.SelectionScene(rawValue: values["selection"]) ?? .threeRows
        stripes = values["stripes"] != LabRGStripes.off.rawValue
    }

    static func today(_ v: RoundValues) -> LabRGLook {
        LabRGLook(values: v, style: .today, align: .right, width: .six, headers: .left, corner: .hash, selected: .number, cross: .stop, doubledRule: true)
    }

    static func proposal(_ v: RoundValues) -> LabRGLook {
        var look = LabRGLook(values: v, style: R.Style(rawValue: v["style"]) ?? .subtle, align: R.Align(rawValue: v["align"]) ?? .right,
                  width: R.Width(rawValue: v["width"]) ?? .fits, headers: R.Headers(rawValue: v["headers"]) ?? .data,
                  corner: R.Corner(rawValue: v["corner"]) ?? .selectAll, selected: R.Selected(rawValue: v["selected"]) ?? .tint,
                  cross: R.StripeCross(rawValue: v["cross"]) ?? .cross, doubledRule: false)
        look.rounded = true
        return look
    }

    func with(style: R.Style) -> LabRGLook {
        var copy = self; copy.style = style; return copy
    }
}

/// The results grid of Echo's card with the gutter in a given look: a header (name over type), the
/// row numbers, and nine rows of sample data from the AdventureWorks salespeople.
struct LabRGCard: View {
    static let width: CGFloat = 700
    static let height: CGFloat = 330
    static let cellHeight: CGFloat = 176

    struct Column { let name: String; let type: String; let width: CGFloat; let isNumeric: Bool }
    static let columns: [Column] = [
        .init(name: "BusinessEntityID", type: "int", width: 130, isNumeric: true),
        .init(name: "TerritoryID", type: "int", width: 100, isNumeric: true),
        .init(name: "SalesQuota", type: "money", width: 110, isNumeric: true),
        .init(name: "Bonus", type: "money", width: 90, isNumeric: true),
        .init(name: "CommissionPct", type: "smallMoney", width: 120, isNumeric: true),
        .init(name: "rowguid", type: "guid", width: 150, isNumeric: false),
    ]
    static let data: [[String]] = [
        ["274", "NULL", "NULL", "0.0000", "0.0000", "48754992-9EE0-4"],
        ["275", "2", "300000.0000", "4100.0000", "0.0120", "1E0A7274-3064-4"],
        ["276", "4", "250000.0000", "2000.0000", "0.0150", "4DD9EEE4-8E81-4"],
        ["277", "3", "250000.0000", "2500.0000", "0.0150", "39012928-BFEC-4"],
        ["278", "6", "250000.0000", "500.0000", "0.0100", "7A0AE1AB-B283-4"],
        ["279", "5", "300000.0000", "6700.0000", "0.0100", "52A5179D-3239-4"],
        ["280", "1", "250000.0000", "5000.0000", "0.0100", "BE941A4A-FB50-4"],
        ["281", "4", "250000.0000", "3550.0000", "0.0100", "35326DDB-7278-4"],
        ["282", "6", "250000.0000", "5000.0000", "0.0150", "31FD7FC1-DC84-4"],
    ]

    let look: LabRGLook
    /// How many rows and columns to draw (a small card in the gallery shows fewer).
    var rowLimit = 9
    var columnLimit = 6

    @Environment(\.workspaceCardCornerRadius) private var cornerRadius
    @State private var hoveredRow: Int?
    @State private var isCornerHovered = false
    @State private var isAllSelected = false

    private let headerHeight: CGFloat = 36
    private let rowHeight: CGFloat = 24
    private let digitWidth: CGFloat = 7.2
    private let laneInset: CGFloat = 5

    private var rowNumbers: [Int] {
        let first: Int = switch look.rows { case .few: 1; case .thousands: 1196; case .millions: 1_203_997 }
        return (0..<rowLimit).map { first + $0 }
    }

    private var selectedRows: Set<Int> {
        if isAllSelected { return Set(0..<rowLimit) }
        switch look.selection {
        case ResultsGutterRound.SelectionScene.none: return []
        case .oneRow: return [3]
        case .threeRows: return [3, 4, 5].filter { $0 < rowLimit }.reduce(into: Set<Int>()) { $0.insert($1) }
        }
    }

    private var digits: Int {
        let widest = String(rowNumbers.last ?? 1).count
        switch look.width {
        case .six: return max(6, widest)
        case .fits: return max(3, widest)
        case .four: return max(4, widest)
        }
    }

    private var gutterWidth: CGFloat {
        let base = CGFloat(digits) * digitWidth
        switch look.style {
        case .today: return base + SpacingTokens.xxxs + SpacingTokens.xxs1
        case .lane: return base + 2 * SpacingTokens.xs + 2 * laneInset
        case .subtle, .hairline, .column: return base + 2 * SpacingTokens.xs
        }
    }

    private var columns: [Column] { Array(Self.columns.prefix(columnLimit)) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            gutterBackground
            gutterTints
            VStack(alignment: .leading, spacing: SpacingTokens.none) {
                headerRow
                ForEach(0..<rowLimit, id: \.self) { index in row(index) }
                Spacer(minLength: 0)
            }
            headerRules
            selectionOutline
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .workspaceCard()
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Workspace.canvas)
    }

    // MARK: - Gutter

    private var hasEdge: Bool { look.style == .today || look.style == .hairline || look.style == .column }

    private var gutterBackground: some View {
        ZStack(alignment: .leading) {
            switch look.style {
            case .column:
                Rectangle().fill(ColorTokens.Workspace.groupFill).frame(width: gutterWidth)
            case .lane:
                RoundedRectangle(cornerRadius: max(cornerRadius - laneInset, SpacingTokens.xxs), style: .continuous)
                    .fill(ColorTokens.Workspace.groupFill)
                    .frame(width: gutterWidth - 2 * laneInset)
                    .padding(laneInset)
                    .frame(width: gutterWidth, alignment: .leading)
            case .today, .subtle, .hairline:
                Color.clear.frame(width: gutterWidth)
            }
            if hasEdge {
                // Below the header only for the Hairline: no vertical line through its header row (Echo today runs it the full height).
                let top = look.style == .column || look.style == .today ? 0 : headerHeight
                Rectangle().fill(ColorTokens.Separator.primary).frame(width: 0.5).padding(.top, top)
                    .frame(maxHeight: .infinity, alignment: .bottom).offset(x: gutterWidth - 0.5)
            }
        }
        .frame(maxHeight: .infinity, alignment: .leading)
    }

    private var cornerCell: some View {
        ZStack {
            if look.corner != .empty {
                Text("#").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
            }
            if look.corner == .selectAll, isAllSelected {
                RoundedRectangle(cornerRadius: SpacingTokens.xxs, style: .continuous)
                    .fill(ColorTokens.accent.opacity(0.18))
                    .padding(SpacingTokens.xxs)
            }
        }
        .frame(width: gutterWidth, height: headerHeight)
        .contentShape(Rectangle())
        .onHover { isCornerHovered = look.corner == .selectAll && $0 }
        .onTapGesture { if look.corner == .selectAll { isAllSelected.toggle() } }
        .help(look.corner == .selectAll ? "Select All" : "")
    }

    private func numberCell(_ index: Int) -> some View {
        let isSelected = selectedRows.contains(index)
        let isHot = isSelected || hoveredRow == index
        return ZStack(alignment: .trailing) {
            if isSelected, look.selected == .tint, !look.rounded {
                Rectangle().fill(ColorTokens.accent.opacity(0.18))
                    .padding(.horizontal, look.style == .lane ? laneInset : 0)
            }
            if isSelected, look.selected == .bar {
                Rectangle().fill(ColorTokens.accent).frame(width: 2)
                    .padding(.trailing, look.style == .lane ? laneInset : 0)
            }
            Text(String(rowNumbers[index]))
                .font(TypographyTokens.caption2.monospacedDigit())
                .foregroundStyle(isHot ? ColorTokens.accent : ColorTokens.Text.tertiary)
                .frame(width: gutterWidth, alignment: look.align == .centre ? .center : .trailing)
                .padding(.trailing, look.align == .centre ? 0 : (look.style == .today ? SpacingTokens.xxs1 : (look.style == .lane ? SpacingTokens.xs + laneInset : SpacingTokens.xs)))
        }
        .frame(width: gutterWidth, height: rowHeight, alignment: .trailing)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: SpacingTokens.none) {
            cornerCell
            ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                headerCell(column)
            }
        }
        .frame(height: headerHeight)
    }

    private func headerAlignment(_ column: Column) -> HorizontalAlignment {
        switch look.headers {
        case .left: .leading
        case .data: column.isNumeric ? .trailing : .leading
        case .centre: .center
        }
    }

    private func headerCell(_ column: Column) -> some View {
        let alignment = headerAlignment(column)
        let frameAlignment: Alignment = alignment == .trailing ? .trailing : (alignment == .center ? .center : .leading)
        return VStack(alignment: alignment, spacing: SpacingTokens.none) {
            Text(column.name).font(TypographyTokens.caption2.weight(.semibold))
            Text(column.type).font(TypographyTokens.label.monospaced()).foregroundStyle(ColorTokens.Text.tertiary)
        }
        .padding(.horizontal, SpacingTokens.xs2)
        .frame(width: column.width, height: headerHeight, alignment: frameAlignment)
        .overlay(alignment: .trailing) { Rectangle().fill(ColorTokens.Separator.primary).frame(width: 0.5, height: SpacingTokens.md) }
    }

    /// One line under the header across the gutter and the columns; Echo today also draws the
    /// system's, 4pt above it, over the columns only.
    private var headerRules: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(ColorTokens.Separator.primary).frame(height: 0.5).offset(y: headerHeight - 0.5)
            if look.doubledRule {
                Rectangle().fill(ColorTokens.Separator.primary).frame(height: 0.5)
                    .padding(.leading, gutterWidth).offset(y: headerHeight - SpacingTokens.xxs - 0.5)
            }
        }
    }

    // MARK: - Rows

    private func row(_ index: Int) -> some View {
        let isStriped = look.stripes && !index.isMultiple(of: 2)
        let isSelected = selectedRows.contains(index)
        let crossesGutter = look.cross == .cross && (look.style == .today || look.style == .subtle || look.style == .hairline)
        return HStack(spacing: SpacingTokens.none) {
            numberCell(index)
                .background { if isStriped && crossesGutter { shade } }
            HStack(spacing: SpacingTokens.none) {
                ForEach(Array(columns.enumerated()), id: \.offset) { position, column in
                    cell(Self.data[index][position], column: column)
                }
            }
            .background {
                if look.rounded {
                    if isStriped { shade }
                } else {
                    (isSelected ? ColorTokens.accent.opacity(0.18) : (isStriped ? ColorTokens.Sidebar.hoverFill : .clear))
                }
            }
        }
        .frame(height: rowHeight)
        .onHover { hoveredRow = $0 ? index : (hoveredRow == index ? nil : hoveredRow) }
    }

    /// A shaded row: the rounded shape when rounded (8pt by 1pt in, 6pt corners), else a plain band.
    @ViewBuilder
    private var shade: some View {
        if look.rounded {
            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(ColorTokens.Sidebar.hoverFill)
                .padding(.horizontal, SpacingTokens.xs).padding(.vertical, 1)
        } else {
            ColorTokens.Sidebar.hoverFill
        }
    }

    private func cell(_ text: String, column: Column) -> some View {
        let isNull = text == "NULL"
        return Text(text)
            .font(TypographyTokens.caption2.monospacedDigit())
            .italic(isNull)
            .foregroundStyle(isNull ? ColorTokens.Text.tertiary : (column.isNumeric ? ColorTokens.accent : ColorTokens.Text.primary))
            .lineLimit(1)
            .padding(.horizontal, SpacingTokens.xs2)
            .frame(width: column.width, alignment: column.isNumeric && !isNull ? .trailing : .leading)
    }

    /// One outline round the selected block, like the grid's (a 1pt accent line at 65%).
    @ViewBuilder
    private var selectionOutline: some View {
        if let first = selectedRows.min(), let last = selectedRows.max() {
            let total = columns.reduce(CGFloat.zero) { $0 + $1.width }
            if look.rounded {
                // As Echo: the range's block inset 2pt at its ends, 6pt corners, a fill and one outline.
                let block = RoundedRectangle(cornerRadius: 6, style: .continuous)
                ZStack {
                    block.fill(ColorTokens.accent.opacity(0.18))
                    block.stroke(ColorTokens.accent.opacity(0.65), lineWidth: 1)
                }
                .frame(width: total, height: CGFloat(last - first + 1) * rowHeight - 4)
                .offset(x: gutterWidth, y: headerHeight + CGFloat(first) * rowHeight + 2)
                .allowsHitTesting(false)
            } else {
                RoundedRectangle(cornerRadius: SpacingTokens.xxs, style: .continuous)
                    .stroke(ColorTokens.accent.opacity(0.65), lineWidth: 1)
                    .frame(width: total, height: CGFloat(last - first + 1) * rowHeight)
                    .offset(x: gutterWidth, y: headerHeight + CGFloat(first) * rowHeight)
                    .allowsHitTesting(false)
            }
        }
    }

    /// The gutter's own tints in the rounded shape: one block for the selected rows, and the hovered
    /// row's hover tint, each inset 4pt from the gutter's sides.
    @ViewBuilder
    private var gutterTints: some View {
        if look.rounded {
            let inset = (look.style == .lane ? laneInset : 0) + SpacingTokens.xxs
            let width = max(gutterWidth - 2 * inset, 0)
            ZStack(alignment: .topLeading) {
                if look.selected == .tint, let first = selectedRows.min(), let last = selectedRows.max() {
                    RoundedRectangle(cornerRadius: 6, style: .continuous).fill(ColorTokens.accent.opacity(0.18))
                        .frame(width: width, height: CGFloat(last - first + 1) * rowHeight - 4)
                        .offset(x: inset, y: headerHeight + CGFloat(first) * rowHeight + 2)
                }
                if let hovered = hoveredRow, !selectedRows.contains(hovered) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous).fill(ColorTokens.Sidebar.hoverFill)
                        .frame(width: width, height: rowHeight - 2)
                        .offset(x: inset, y: headerHeight + CGFloat(hovered) * rowHeight + 1)
                }
            }
            .allowsHitTesting(false)
        }
    }
}

/// The five gutters and Echo today on the same rows, in a grid of small cards.
struct LabRGStyles: View {
    let values: RoundValues
    private typealias S = ResultsGutterRound.Style

    var body: some View {
        let base = LabRGLook.proposal(values)
        let cells: [(String, LabRGLook)] = [
            ("Echo today", LabRGLook.today(values)),
            (S.subtle.rawValue, base.with(style: .subtle)),
            (S.hairline.rawValue, base.with(style: .hairline)),
            (S.column.rawValue, base.with(style: .column)),
            (S.lane.rawValue, base.with(style: .lane)),
            ("Your settings", base),
        ]
        Grid(horizontalSpacing: SpacingTokens.sm, verticalSpacing: SpacingTokens.sm) {
            ForEach(0..<3, id: \.self) { rowIndex in
                GridRow {
                    ForEach(0..<2, id: \.self) { column in
                        let cell = cells[rowIndex * 2 + column]
                        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                            Text(cell.0).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary).lineLimit(1)
                            LabRGCard(look: cell.1, rowLimit: 4, columnLimit: 3)
                        }
                        .frame(height: LabRGCard.cellHeight)
                    }
                }
            }
        }
    }
}
