import EchoSense
import SwiftUI

/// The run note (QE2), the zoom control, the empty tab's starting points (QE6) and the outline edge (QE5).
extension LabQEEditor {
    @ViewBuilder
    func runNote(_ layout: LabQELayout, width: CGFloat) -> some View {
        if let result = scene.runNote, let ran = LabQESample.statements.first {
            let range = NSRange(location: 0, length: 1)
            let note: QueryRunNote? = switch result {
            case .rows(let rows, let seconds): QueryRunNote.success(range: range, rows: rows, hasResults: true, duration: seconds)
            case .error: QueryRunNote.shortFailure(range: range, message: LabQESample.serverErrorMessage)
            }
            if let note {
                let lastLine = lines[ran.upperBound - 1]
                let label = runNoteLabel(note)
                    .fixedSize()
                    .frame(height: layout.lineHeight)
                switch style.runNotePlace {
                case .lineEnd:
                    label.offset(x: layout.x(column: lastLine.count) + LayoutTokens.EditorGutter.runNoteGap, y: layout.y(line: ran.upperBound))
                case .rightEdge:
                    label.frame(width: max(width - SpacingTokens.md, 0), alignment: .trailing)
                        .offset(y: layout.y(line: ran.upperBound))
                }
            }
        }
    }

    private func runNoteLabel(_ note: QueryRunNote) -> some View {
        LabQERunNoteLabel(look: style.runNoteLook, note: note)
    }

    @ViewBuilder
    var zoomOverlay: some View {
        if let place = style.zoomPlace, place == .bottomLeft || place == .bottomRight, zoomIsVisible {
            zoomControl.padding(SpacingTokens.xs).transition(.opacity)
        }
    }

    private var zoomIsVisible: Bool {
        switch style.zoomShows {
        case .always: true
        case .notDefault: style.zoom != .z100
        case .hover: isHoveringEditor
        }
    }

    var zoomControl: some View {
        LabQEZoomControl(look: style.zoomLook, zoom: style.zoom) { onZoom?($0) }
    }

    @ViewBuilder
    var bezel: some View {
        if style.zoomPlace == .keysOnly, showsBezel {
            Text(style.zoom.rawValue)
                .font(TypographyTokens.title)
                .padding(.horizontal, SpacingTokens.lg)
                .padding(.vertical, SpacingTokens.sm)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpacingTokens.md, style: .continuous))
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }

    /// The footer under the editor (Z3): the connection chip and the zoom beside it.
    var footer: some View {
        HStack(spacing: SpacingTokens.xs) {
            Text(verbatim: "dkloosql10-d · ccsLDK17")
                .font(TypographyTokens.detail)
                .padding(.horizontal, SpacingTokens.sm)
                .padding(.vertical, SpacingTokens.xxs2)
                .glassEffect(.regular, in: .capsule)
            if zoomIsVisible { zoomControl }
            Spacer(minLength: SpacingTokens.none)
        }
    }

    func hintsView(_ place: LabQEHintsPlace, _ layout: LabQELayout) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text(verbatim: "Start typing, or begin with a recent table or a snippet")
                .font(place == .today ? TypographyTokens.standard : Font(layout.codeFont))
                .foregroundStyle(ColorTokens.Text.tertiary)
                .frame(height: place == .today ? nil : layout.lineHeight)
            HStack(spacing: SpacingTokens.xxs2) {
                ForEach(["orders", "customers", "order_lines"], id: \.self) { chip(Label($0, systemImage: "tablecells")) }
            }
            HStack(spacing: SpacingTokens.xxs2) {
                ForEach(["SELECT", "INSERT", "UPDATE", "CREATE TABLE"], id: \.self) { chip(Text(verbatim: $0)) }
            }
        }
        .offset(x: place == .today ? Self.hintsLeading : layout.codeX,
                y: place == .today ? Self.hintsTop : layout.top)
    }

    /// Echo's `LayoutTokens.EmptyQueryHints` (defined in the app): 52pt in, 32pt down.
    static var hintsLeading: CGFloat { 52 }
    static var hintsTop: CGFloat { SpacingTokens.xl }

    private func chip(_ label: some View) -> some View {
        label.font(TypographyTokens.detail)
            .foregroundStyle(ColorTokens.Text.secondary)
            .padding(.horizontal, SpacingTokens.xs)
            .padding(.vertical, SpacingTokens.xxxs)
            .background(ColorTokens.Text.primary.opacity(0.05), in: Capsule())
    }

    /// QE5: the strip on the right edge in place of the scroll bar.
    func outlineStrip(height: CGFloat) -> some View {
        let lineCount = CGFloat(max(lines.count - 1, 1))
        let track = max(height - SpacingTokens.xs * 2, 0)
        return ZStack(alignment: .top) {
            Capsule().fill(ColorTokens.Text.primary.opacity(0.05))
            Capsule().fill(ColorTokens.accent.opacity(0.18)).frame(height: track * 0.7).frame(maxHeight: .infinity, alignment: .top)
            ForEach(LabQESample.statements, id: \.lowerBound) { statement in
                Capsule().fill(ColorTokens.Text.tertiary).frame(height: SpacingTokens.xxxs)
                    .offset(y: track * CGFloat(statement.lowerBound - 1) / lineCount)
            }
            if hasError {
                Capsule().fill(ColorTokens.Status.error).frame(height: SpacingTokens.xxxs)
                    .offset(y: track * CGFloat(LabQESample.error.line - 1) / lineCount)
            }
        }
        .frame(width: SpacingTokens.xxs, height: track)
        .offset(x: 0, y: SpacingTokens.xs)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, SpacingTokens.xxs)
    }
}

/// The zoom control in its three looks. Clicking the steps or a menu item changes the zoom.
struct LabQEZoomControl: View {
    let look: LabQEZoomLook
    let zoom: LabQEZoomLevel
    let onZoom: (LabQEZoomLevel) -> Void

    var body: some View {
        Group {
            switch look {
            case .stepper:
                HStack(spacing: SpacingTokens.xxs) {
                    step(-1, symbol: "minus")
                    Text(zoom.rawValue).monospacedDigit().frame(minWidth: SpacingTokens.xl)
                    step(1, symbol: "plus")
                }
            case .menu, .magnifier:
                Menu {
                    ForEach(LabQEZoomLevel.allCases, id: \.self) { level in
                        Button(level.rawValue) { onZoom(level) }
                    }
                    Divider()
                    Button("Actual Size") { onZoom(.z100) }
                } label: {
                    HStack(spacing: SpacingTokens.xxs) {
                        if look == .magnifier { Image(systemName: "plus.magnifyingglass") }
                        Text(zoom.rawValue).monospacedDigit()
                    }
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(look == .menu ? .visible : .hidden)
                .fixedSize()
            }
        }
        .font(TypographyTokens.detail)
        .foregroundStyle(ColorTokens.Text.secondary)
        .padding(.horizontal, SpacingTokens.xs)
        .padding(.vertical, SpacingTokens.xxs)
        .glassEffect(.regular, in: .capsule)
        .help("Zoom (⌘+ ⌘− ⌘0)")
    }

    private func step(_ direction: Int, symbol: String) -> some View {
        Button {
            let all = LabQEZoomLevel.allCases
            if let index = all.firstIndex(of: zoom), all.indices.contains(index + direction) { onZoom(all[index + direction]) }
        } label: {
            Image(systemName: symbol).frame(width: SpacingTokens.sm, height: SpacingTokens.sm).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
