import Foundation

/// One column of the stage: Echo today, an option, the live Mix, or a pinned Mix.
public struct StageColumn: Equatable, Identifiable {
    public enum Kind: Equatable { case today, option, liveMix, pinnedMix }
    public var id: String
    public var kind: Kind
    public var title: String
    /// The specimen to draw.
    public var specimenID: String
    /// Control values this column is drawn with.
    public var controls: [String: String]
    public var designWidth: Double
    public var designHeight: Double
    public var isNew: Bool

    public init(id: String, kind: Kind, title: String, specimenID: String, controls: [String: String],
                designWidth: Double, designHeight: Double, isNew: Bool = false) {
        self.id = id; self.kind = kind; self.title = title; self.specimenID = specimenID; self.controls = controls
        self.designWidth = designWidth; self.designHeight = designHeight; self.isNew = isNew
    }

    public var isToday: Bool { kind == .today }
    public var isMix: Bool { kind == .liveMix || kind == .pinnedMix }
    /// Pick / Maybe / No belongs to real options only.
    public var takesVerdict: Bool { kind == .option }
}

public enum StageColumns {
    public static let defaultDesignWidth: Double = 340
    public static let defaultDesignHeight: Double = 200
    public static let liveMixID = "mix.live"

    /// Control values for a Mix: the owner's answers to control questions, then the preview for everything else.
    public static func mixControls(manifest: StageManifest, state: StageState) -> [String: String] {
        var values = manifest.defaultControlValues
        for (k, v) in state.controlValues { values[k] = v }
        for c in manifest.controls where c.question != nil {
            if let a = state.answers[c.id], c.choices.contains(where: { $0.id == a }) { values[c.id] = a }
        }
        return values
    }

    /// All columns in drawing order: Echo today first, the options (all or the shown ones), the live Mix, the pinned Mixes.
    public static func columns(manifest: StageManifest, state: StageState) -> [StageColumn] {
        var out: [StageColumn] = []
        let preview = previewControls(manifest: manifest, state: state)
        if let t = manifest.echoToday {
            out.append(make(t, id: t.id, kind: .today, title: t.title, controls: preview))
        }
        for s in options(manifest: manifest, state: state) {
            out.append(make(s, id: s.id, kind: .option, title: s.title, controls: preview))
        }
        if let base = manifest.mixSpecimenID.flatMap({ manifest.specimen($0) }) {
            if state.showLiveMix {
                out.append(make(base, id: liveMixID, kind: .liveMix, title: "Mix · your answers",
                                controls: mixControls(manifest: manifest, state: state)))
            }
            for m in state.pinnedMixes {
                out.append(make(base, id: m.id, kind: .pinnedMix, title: m.title, controls: m.controls))
            }
        }
        return out
    }

    /// Option specimens that are shown (a `nil` filter shows all).
    public static func options(manifest: StageManifest, state: StageState) -> [StageSpecimen] {
        let all = manifest.proposalSpecimens
        guard let shown = state.shownOptions else { return all }
        let filtered = all.filter { shown.contains($0.id) }
        return filtered.isEmpty ? all : filtered
    }

    /// The preview shows the controls as set. Echo today never reads them, so it is drawn with the same values; it ignores them.
    public static func previewControls(manifest: StageManifest, state: StageState) -> [String: String] {
        var values = manifest.defaultControlValues
        for (k, v) in state.controlValues { values[k] = v }
        return values
    }

    private static func make(_ s: StageSpecimen, id: String, kind: StageColumn.Kind, title: String, controls: [String: String]) -> StageColumn {
        StageColumn(id: id, kind: kind, title: title, specimenID: s.id, controls: controls,
                    designWidth: s.designWidth ?? defaultDesignWidth, designHeight: s.designHeight ?? defaultDesignHeight)
    }

    /// Side by side up to three columns, a filmstrip beyond (decision H2).
    public static let sideBySideLimit = 3

    public static func usesFilmstrip(columnCount: Int) -> Bool { columnCount > sideBySideLimit }

    /// Columns an arrow key moves through: everything except Echo today.
    public static func navigable(_ columns: [StageColumn]) -> [StageColumn] { columns.filter { !$0.isToday } }

    /// The next navigable column id, wrapping. `current` may be nil or stale.
    public static func step(from current: String?, by delta: Int, in columns: [StageColumn]) -> String? {
        let nav = navigable(columns)
        guard !nav.isEmpty else { return nil }
        guard let cur = current, let i = nav.firstIndex(where: { $0.id == cur }) else {
            return delta >= 0 ? nav.first?.id : nav.last?.id
        }
        let n = nav.count
        let j = ((i + delta) % n + n) % n
        return nav[j].id
    }

    /// The column the compare modes use, falling back to the first navigable one.
    public static func selectedColumn(_ columns: [StageColumn], selected: String?) -> StageColumn? {
        let nav = navigable(columns)
        if let s = selected, let c = nav.first(where: { $0.id == s }) { return c }
        return nav.first
    }

    /// The next free pinned Mix title: Mix 1, Mix 2, ...
    public static func nextMixNumber(_ pinned: [StageMixColumn]) -> Int {
        var n = 1
        let used = Set(pinned.map { $0.id })
        while used.contains("mix.\(n)") { n += 1 }
        return n
    }
}

// MARK: - Matrix

public struct StageMatrixCell: Equatable {
    public var scenarioID: String
    public var columnID: String
    public var height: Double?
    public var todayHeight: Double?
    /// Outlined: the height differs from Echo today by more than the threshold.
    public var differs: Bool
}

public enum StageMatrix {
    /// Points of height difference above which a cell is outlined (decision H3, prototype `est`).
    public static let threshold: Double = 14

    /// The difference rule. Strictly more than 14pt; Echo today itself never differs; unknown sizes never differ.
    public static func differs(height: Double?, todayHeight: Double?, isToday: Bool = false, threshold: Double = StageMatrix.threshold) -> Bool {
        if isToday { return false }
        guard let h = height, let t = todayHeight else { return false }
        return abs(h - t) > threshold
    }

    /// Every applicable scenario by every column. `height` supplies the measured height of a column in a scenario.
    public static func cells(columns: [StageColumn], scenarios: [StageScenario],
                             height: (StageColumn, String) -> Double?) -> [[StageMatrixCell]] {
        let today = columns.first(where: { $0.isToday })
        var rows: [[StageMatrixCell]] = []
        for sc in scenarios where sc.applicable {
            let todayH: Double? = today.flatMap { height($0, sc.id) }
            var row: [StageMatrixCell] = []
            for col in columns {
                let h = height(col, sc.id)
                let d = differs(height: h, todayHeight: todayH, isToday: col.isToday)
                row.append(StageMatrixCell(scenarioID: sc.id, columnID: col.id, height: h, todayHeight: todayH, differs: d))
            }
            rows.append(row)
        }
        return rows
    }
}

// MARK: - Zoom

public enum StageZoom {
    /// 100% is Echo's real size; up to 200% (decision H9).
    public static let steps: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    public static func clamp(_ z: Double) -> Double { min(max(z, 0.25), 2.0) }

    /// The scale a specimen is drawn at. When the zoomed width does not fit, it is scaled down and `fitted` is true
    /// (the stage shows a label such as "Scaled to 74% to fit").
    public static func effectiveScale(zoom: Double, designWidth: Double, available: Double) -> (scale: Double, fitted: Bool) {
        let z = clamp(zoom)
        guard designWidth > 0, available > 0 else { return (z, false) }
        let wanted = designWidth * z
        if wanted <= available { return (z, false) }
        return (available / designWidth, true)
    }

    public static func label(scale: Double) -> String { "\(Int((scale * 100).rounded()))%" }

    /// The next step up or down from the current zoom.
    public static func nextStep(from z: Double, up: Bool) -> Double {
        if up { return steps.first(where: { $0 > z + 0.001 }) ?? steps.last ?? z }
        return steps.last(where: { $0 < z - 0.001 }) ?? steps.first ?? z
    }
}

// MARK: - Redlines and motion marks

/// A measurement drawn over a specimen, in the specimen's own units (decision H8).
public struct StageRedline: Equatable, Identifiable {
    public enum Kind: String, Codable { case padding, gap, size }
    public var id: String
    public var kind: Kind
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var label: String
    public init(id: String, kind: Kind, x: Double, y: Double, width: Double, height: Double, label: String) {
        self.id = id; self.kind = kind; self.x = x; self.y = y; self.width = width; self.height = height; self.label = label
    }
}

/// A tagged part's life on the timeline of a motion specimen (decision H18).
public struct StageMotionMark: Equatable, Identifiable {
    public var id: String
    public var label: String
    public var start: Double
    public var end: Double
    public init(id: String, label: String, start: Double, end: Double) {
        self.id = id; self.label = label; self.start = start; self.end = end
    }
}
