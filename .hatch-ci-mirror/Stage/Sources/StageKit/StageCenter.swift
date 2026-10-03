import SwiftUI
import StageCore

func stageShortTitle(_ title: String) -> String {
    let parts = title.components(separatedBy: " ·")
    return parts.first ?? title
}

/// The middle of the window: scenario strip, the specimens in the chosen compare mode, the transport bar, the pin composer.
struct StageCenter: View {
    @ObservedObject var model: StageModel

    var body: some View {
        let palette = model.palette
        let scheme: ColorScheme = model.state.appearance == .dark ? .dark : .light
        VStack(spacing: 0) {
            ScenarioStrip(model: model)
                .padding(12)
            GeometryReader { geo in
                ScrollView(.vertical) {
                    modeContent(width: max(geo.size.width - 24, 100))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            if model.motionDuration != nil {
                Divider()
                TransportBar(model: model)
            }
            if model.pinDraft != nil {
                Divider()
                PinComposer(model: model)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background)
        .foregroundStyle(palette.text)
        .environment(\.colorScheme, scheme)
    }

    @ViewBuilder
    private func modeContent(width: CGFloat) -> some View {
        switch model.state.mode {
        case .side:
            SideBySideView(model: model, width: width)
        case .matrix:
            MatrixView(model: model, width: width)
        case .flip, .overlay, .wipe:
            CompareView(model: model, width: width)
        }
    }
}

// MARK: - Scenario strip (decisions H5, H6)

struct ScenarioStrip: View {
    @ObservedObject var model: StageModel

    private var notApplicable: [StageScenario] {
        model.manifest.effectiveScenarios.filter { !$0.applicable }
    }

    var body: some View {
        let palette = model.palette
        HStack(alignment: .top, spacing: 8) {
            StageFlow(spacing: 6) {
                ForEach(model.manifest.effectiveScenarios, id: \.id) { sc in
                    if sc.applicable {
                        Button {
                            model.send(.setScenario(sc.id))
                        } label: {
                            chip(sc.title, selected: model.state.scenario == sc.id, palette: palette)
                        }
                        .buttonStyle(.plain)
                        .help("Show every specimen in the \(sc.title) state. Key S moves to the next one.")
                    } else {
                        chip("\(sc.title) · n/a", selected: false, palette: palette)
                            .opacity(0.55)
                            .overlay(Capsule().strokeBorder(palette.muted, style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
                            .help("Not applicable: \(sc.notApplicableReason ?? "no reason given")")
                    }
                }
            }
            if !notApplicable.isEmpty {
                Menu {
                    ForEach(notApplicable, id: \.id) { sc in
                        Text("\(sc.title): \(sc.notApplicableReason ?? "no reason given")")
                    }
                } label: {
                    Text("Why n/a?")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            Spacer(minLength: 0)
        }
    }

    private func chip(_ title: String, selected: Bool, palette: StagePalette) -> some View {
        Text(title)
            .font(.system(size: 11))
            .foregroundStyle(selected ? Color.white : palette.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Capsule().fill(selected ? palette.accent : palette.card))
            .overlay(Capsule().strokeBorder(selected ? palette.accent : palette.line, lineWidth: 1))
    }
}

// MARK: - Side by side and filmstrip (decision H2)

struct SideBySideView: View {
    @ObservedObject var model: StageModel
    let width: CGFloat

    var body: some View {
        let all = model.columns
        if StageColumns.usesFilmstrip(columnCount: all.count) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(model.visibleColumns, id: \.id) { column in
                        ColumnView(model: model, column: column)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
                FilmstripView(model: model, columns: all, width: width)
                Text("Four or more columns: two are shown large, the rest sit in the filmstrip. Arrow keys move through it, Space flips with Echo today.")
                    .font(.caption)
                    .foregroundStyle(model.palette.muted)
            }
        } else {
            HStack(alignment: .top, spacing: 12) {
                ForEach(all, id: \.id) { column in
                    ColumnView(model: model, column: column)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
    }
}

struct ColumnView: View {
    @ObservedObject var model: StageModel
    let column: StageColumn

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ColumnHeader(model: model, column: column)
            SpecimenSlot(model: model, column: column, scenario: model.state.scenario)
            if column.takesVerdict {
                TextField(
                    "Note on this option (Return to send)",
                    text: model.binding({ $0.optionNotes[column.specimenID] ?? "" }, { StageAction.setOptionNote(option: column.specimenID, text: $0) })
                )
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .onSubmit { model.send(.commitOptionNote(option: column.specimenID)) }
            }
            if let spec = model.manifest.specimen(column.specimenID), !spec.summary.isEmpty, column.kind != .liveMix {
                Text(spec.summary)
                    .font(.caption2)
                    .foregroundStyle(model.palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct ColumnHeader: View {
    @ObservedObject var model: StageModel
    let column: StageColumn

    private var isSelected: Bool {
        !column.isToday && model.state.selected == column.id
    }

    var body: some View {
        let palette = model.palette
        StageFlow(spacing: 6) {
            HStack(spacing: 4) {
                if isSelected {
                    Circle().fill(palette.accent).frame(width: 6, height: 6)
                }
                Text(column.title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
            }
            if column.isToday { matchBadge(palette) }
            if column.isMix { badge("Mix", palette.muted, palette.line) }
            if let spec = model.manifest.specimen(column.specimenID), column.kind == .option, model.manifest.isNew(addedIn: spec.addedIn) {
                NewBadge()
            }
            if column.takesVerdict { verdictButtons(palette) }
            if column.kind == .pinnedMix {
                Button {
                    model.send(.removeMix(column.id))
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.plain)
                .help("Remove \(column.title)")
            }
        }
    }

    private func badge(_ text: String, _ color: Color, _ stroke: Color) -> some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(stroke, lineWidth: 1))
    }

    @ViewBuilder
    private func matchBadge(_ palette: StagePalette) -> some View {
        let spec = model.manifest.specimen(column.specimenID)
        if spec?.matchStale == true {
            HStack(spacing: 3) {
                Image(systemName: "exclamationmark.triangle")
                Text("Echo changed since this was checked")
            }
            .font(.system(size: 10))
            .foregroundStyle(palette.error)
            .help("The specimen may no longer match the real Echo. Judge with care.")
        } else {
            HStack(spacing: 3) {
                Image(systemName: "checkmark.seal")
                Text("Match · \(spec?.matchNote ?? "not checked yet")")
            }
            .font(.system(size: 10))
            .foregroundStyle(palette.ok)
            .help("Last checked against the real Echo.")
        }
    }

    private func verdictButtons(_ palette: StagePalette) -> some View {
        HStack(spacing: 3) {
            ForEach(StageVerdict.allCases, id: \.self) { verdict in
                let on: Bool = model.state.verdicts[column.specimenID] == verdict
                Button {
                    model.send(.setVerdict(option: column.specimenID, verdict: verdict))
                } label: {
                    Text(verdict.title)
                        .font(.system(size: 10))
                        .foregroundStyle(on ? Color.white : palette.text)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(RoundedRectangle(cornerRadius: 5).fill(on ? palette.accent : palette.card))
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(on ? palette.accent : palette.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct FilmstripView: View {
    @ObservedObject var model: StageModel
    let columns: [StageColumn]
    let width: CGFloat

    var body: some View {
        let palette = model.palette
        let items = StageColumns.navigable(columns)
        let each: CGFloat = max((width - CGFloat(items.count) * 6) / CGFloat(max(items.count, 1)), 60)
        HStack(alignment: .top, spacing: 6) {
            ForEach(items, id: \.id) { column in
                let selected: Bool = model.state.selected == column.id
                let design = model.designSize(for: column)
                let scale: CGFloat = min(0.4, (each - 12) / max(design.width, 1))
                Button {
                    model.send(.selectOption(column.id))
                } label: {
                    VStack(spacing: 3) {
                        Text(stageShortTitle(column.title))
                            .font(.system(size: 10))
                            .lineLimit(1)
                        SpecimenCanvas(model: model, column: column, scenario: model.state.scenario, scale: scale,
                                       showRedlines: false, allowMotion: false)
                    }
                    .padding(5)
                    .frame(width: each)
                    .background(RoundedRectangle(cornerRadius: 8).fill(palette.card))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(selected ? palette.accent : palette.line, lineWidth: selected ? 1.5 : 1))
                }
                .buttonStyle(.plain)
                .help(column.title)
            }
        }
    }
}

// MARK: - Flip, Overlay, Wipe (decision H3)

struct WipeShape: Shape {
    var fraction: Double

    func path(in rect: CGRect) -> Path {
        Path(CGRect(x: rect.minX, y: rect.minY, width: rect.width * CGFloat(fraction), height: rect.height))
    }
}

struct CompareView: View {
    @ObservedObject var model: StageModel
    let width: CGFloat

    private var today: StageColumn? { model.columns.first(where: { $0.isToday }) }

    var body: some View {
        let other = model.selectedColumn
        VStack(alignment: .leading, spacing: 10) {
            header
            if let t = today, let o = other {
                switch model.state.mode {
                case .flip:
                    flipBody(t, o)
                case .overlay:
                    layeredBody(t, o, wipe: false)
                default:
                    layeredBody(t, o, wipe: true)
                }
            } else {
                Text("Comparing needs Echo today and at least one option.")
                    .font(.callout)
                    .foregroundStyle(model.palette.muted)
            }
        }
    }

    private var header: some View {
        let items = StageColumns.navigable(model.columns)
        return HStack(spacing: 8) {
            Text(model.state.mode.title).font(.system(size: 11, weight: .semibold))
            Text("Echo today vs")
                .font(.system(size: 10))
                .foregroundStyle(model.palette.muted)
            Picker("Compare with", selection: model.binding({ $0.selected ?? "" }, { StageAction.selectOption($0) })) {
                ForEach(items, id: \.id) { c in
                    Text(stageShortTitle(c.title)).tag(c.id)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
            Spacer()
        }
    }

    private func flipBody(_ t: StageColumn, _ o: StageColumn) -> some View {
        let shown: StageColumn = model.state.flipSide ? o : t
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Showing: \(shown.title)").font(.system(size: 12, weight: .semibold))
                Spacer()
                Button {
                    model.send(.flip)
                } label: {
                    Text("Flip (Space)")
                }
            }
            SpecimenSlot(model: model, column: shown, scenario: model.state.scenario)
        }
    }

    private func layeredBody(_ t: StageColumn, _ o: StageColumn, wipe: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(wipe ? "Reveal" : "Option opacity").font(.system(size: 11))
                if wipe {
                    Slider(value: model.binding({ $0.wipePosition }, { StageAction.setWipePosition($0) }), in: 0...1)
                } else {
                    Slider(value: model.binding({ $0.overlayOpacity }, { StageAction.setOverlayOpacity($0) }), in: 0...1)
                }
            }
            LayeredSlot(model: model, today: t, other: o, wipe: wipe)
        }
    }
}

struct LayeredSlot: View {
    @ObservedObject var model: StageModel
    let today: StageColumn
    let other: StageColumn
    let wipe: Bool

    var body: some View {
        let palette = model.palette
        let a = model.designSize(for: today)
        let b = model.designSize(for: other)
        let designHeight: CGFloat = max(a.height, b.height)
        let designWidth: CGFloat = max(a.width, b.width)
        let zoom = StageZoom.clamp(model.state.zoom)
        GeometryReader { geo in
            let avail: Double = Double(max(geo.size.width - 24, 1))
            let fit = StageZoom.effectiveScale(zoom: zoom, designWidth: Double(designWidth), available: avail)
            let scale = CGFloat(fit.scale)
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(palette.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                ZStack(alignment: .top) {
                    CenteredCanvas(model: model, column: today, scale: scale, showRedlines: false)
                    topLayer(scale: scale)
                }
                .padding(12)
                if wipe {
                    wipeDivider(palette)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if fit.fitted {
                    Text("Scaled to \(StageZoom.label(scale: fit.scale)) to fit")
                        .font(.system(size: 10))
                        .foregroundStyle(palette.muted)
                        .padding(6)
                }
            }
        }
        .frame(height: designHeight * CGFloat(zoom) + 24)
    }

    @ViewBuilder
    private func topLayer(scale: CGFloat) -> some View {
        if wipe {
            CenteredCanvas(model: model, column: other, scale: scale, showRedlines: true)
                .clipShape(WipeShape(fraction: model.state.wipePosition))
        } else {
            CenteredCanvas(model: model, column: other, scale: scale, showRedlines: true)
                .opacity(model.state.overlayOpacity)
        }
    }

    private func wipeDivider(_ palette: StagePalette) -> some View {
        GeometryReader { g in
            Rectangle()
                .fill(palette.accent)
                .frame(width: 2, height: g.size.height - 24)
                .offset(x: 12 + (g.size.width - 24) * CGFloat(model.state.wipePosition) - 1, y: 12)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Matrix (decision H5)

struct MatrixView: View {
    @ObservedObject var model: StageModel
    let width: CGFloat

    var body: some View {
        let palette = model.palette
        let columns = model.columns
        let rows = StageMatrix.cells(columns: columns, scenarios: model.manifest.effectiveScenarios) { column, scenario in
            model.measuredHeight(column, scenario: scenario)
        }
        let labelWidth: CGFloat = 84
        let count: CGFloat = CGFloat(max(columns.count, 1))
        let cellWidth: CGFloat = max((width - labelWidth - count * 10) / count, 70)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text("").frame(width: labelWidth)
                ForEach(columns, id: \.id) { column in
                    Text(stageShortTitle(column.title))
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(palette.muted)
                        .frame(width: cellWidth, alignment: .leading)
                }
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 10) {
                    Text(scenarioTitle(row.first?.scenarioID ?? ""))
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(palette.muted)
                        .frame(width: labelWidth, alignment: .leading)
                    ForEach(Array(row.enumerated()), id: \.offset) { index, cell in
                        MatrixCellView(model: model, column: columns[index], cell: cell, cellWidth: cellWidth)
                    }
                }
            }
            Text("Outlined: height differs from Echo today by more than \(Int(StageMatrix.threshold))pt in that scenario.")
                .font(.system(size: 10.5))
                .foregroundStyle(palette.muted)
            ForEach(model.manifest.effectiveScenarios.filter { !$0.applicable }, id: \.id) { sc in
                Text("n/a · \(sc.title): \(sc.notApplicableReason ?? "no reason given")")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.muted)
            }
        }
    }

    private func scenarioTitle(_ id: String) -> String {
        model.manifest.effectiveScenarios.first(where: { $0.id == id })?.title ?? id
    }
}

struct MatrixCellView: View {
    @ObservedObject var model: StageModel
    let column: StageColumn
    let cell: StageMatrixCell
    let cellWidth: CGFloat

    var body: some View {
        let palette = model.palette
        let design = model.designSize(for: column)
        let scale: CGFloat = min(0.6, (cellWidth - 8) / max(design.width, 1))
        VStack(alignment: .leading, spacing: 2) {
            SpecimenCanvas(model: model, column: column, scenario: cell.scenarioID, scale: scale, showRedlines: false, allowMotion: false)
                .padding(4)
                .frame(width: cellWidth, alignment: .topLeading)
                .background(RoundedRectangle(cornerRadius: 8).fill(palette.card.opacity(0.4)))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(cell.differs ? palette.error : Color.clear, lineWidth: 2)
                )
            if cell.differs, let h = cell.height, let t = cell.todayHeight {
                Text("\(Int(h.rounded())) pt vs \(Int(t.rounded())) pt")
                    .font(.system(size: 9.5))
                    .foregroundStyle(palette.error)
            }
        }
    }
}
