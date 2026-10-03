import SwiftUI
import Combine
import StageCore

/// Where the owner clicked to drop a pin; the composer asks for the text.
struct StagePinDraft: Equatable {
    var option: String?
    var x: Double
    var y: Double
}

/// The Stage's one observable object: the manifest, the state, the provider of specimens and the data source.
/// Every user action goes through `send`, which runs the pure reducer and then performs its effects (in order, off the UI path).
@MainActor
public final class StageModel: ObservableObject {
    @Published public private(set) var manifest: StageManifest
    @Published public private(set) var state: StageState
    @Published var pinDraft: StagePinDraft? = nil
    @Published var pinDraftText: String = ""
    /// A problem worth showing: Hatch is away, or something was refused.
    @Published public private(set) var notice: String? = nil
    /// Writes waiting for Hatch (decision S7).
    @Published public private(set) var pendingWrites: Int = 0

    public let provider: any SpecimenProvider
    let dataSource: StageDataSource
    private var persistTask: Task<Void, Never>? = nil
    private var effectChain: Task<Void, Never>? = nil

    public init(manifest: StageManifest, provider: any SpecimenProvider, dataSource: StageDataSource, state: StageState? = nil) {
        self.manifest = manifest
        self.provider = provider
        self.dataSource = dataSource
        var initial = state ?? StageState(manifest: manifest)
        StageReducer.reconcile(&initial, manifest: manifest)
        self.state = initial
    }

    // MARK: Actions

    public func send(_ action: StageAction) {
        var next = state
        let effects = StageReducer.reduce(&next, action, manifest: manifest)
        if next != state { state = next }
        perform(effects)
        if !isTick(action) { schedulePersist() }
    }

    private func isTick(_ action: StageAction) -> Bool {
        if case .tick = action { return true }
        return false
    }

    /// A two-way binding for a part of the state; writes go through the reducer.
    func binding<T>(_ read: @escaping (StageState) -> T, _ write: @escaping (T) -> StageAction) -> Binding<T> {
        Binding<T>(get: { [unowned self] in read(self.state) }, set: { [unowned self] value in self.send(write(value)) })
    }

    // MARK: Loading and saving

    /// Loads what was remembered for this ticket, if anything. Called once when the window appears.
    public func restore() async {
        do {
            if var saved = try await dataSource.loadState() {
                StageReducer.reconcile(&saved, manifest: manifest)
                state = saved
            }
        } catch {
            notice = "Could not load your earlier settings: \(error)"
        }
        pendingWrites = await dataSource.pendingCount()
    }

    /// Replaces the manifest when Hatch offers a new revision (the Reload button).
    public func reload() async {
        do {
            let fresh = try await dataSource.loadManifest()
            var next = state
            manifest = fresh
            StageReducer.reconcile(&next, manifest: fresh)
            state = next
        } catch {
            notice = "Could not reload: \(error)"
        }
    }

    private func schedulePersist() {
        persistTask?.cancel()
        let source = dataSource
        persistTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            if Task.isCancelled { return }
            guard let snapshot = self?.state else { return }
            await source.saveState(snapshot)
        }
    }

    // MARK: Effects

    private func perform(_ effects: [StageEffect]) {
        if effects.isEmpty { return }
        let source = dataSource
        let previous = effectChain
        effectChain = Task { [weak self] in
            await previous?.value
            for effect in effects {
                do {
                    let delivery = try await source.perform(effect)
                    if delivery == .queued { self?.noteQueued() }
                } catch {
                    self?.report(error, for: effect)
                }
            }
            let waiting = await source.pendingCount()
            self?.pendingWrites = waiting
        }
    }

    private func noteQueued() {
        notice = "Hatch is not running. Your picks are kept here and sent when it is back."
    }

    private func report(_ error: Error, for effect: StageEffect) {
        switch effect {
        case .accept, .sendBack:
            var next = state
            next.outcome = "Hatch did not get it: \(error). Nothing was started. Press the button again when Hatch is running."
            state = next
        default:
            notice = "Could not send to Hatch: \(error)"
        }
    }

    public func dismissNotice() { notice = nil }

    // MARK: Derived values for the views

    var columns: [StageColumn] { StageColumns.columns(manifest: manifest, state: state) }

    var selectedColumn: StageColumn? { StageColumns.selectedColumn(columns, selected: state.selected) }

    var palette: StagePalette {
        StagePalette.resolve(dark: state.appearance == .dark, contrast: state.increaseContrast)
    }

    var scenarioTitle: String {
        manifest.effectiveScenarios.first(where: { $0.id == state.scenario })?.title ?? state.scenario
    }

    /// The design size: the provider is the truth, the manifest the fallback.
    func designSize(for column: StageColumn) -> CGSize {
        let size = provider.designSize(for: column.specimenID)
        if size.width > 0 && size.height > 0 { return size }
        return CGSize(width: column.designWidth, height: column.designHeight)
    }

    func measuredHeight(_ column: StageColumn, scenario: String) -> Double? {
        provider.measuredHeight(id: column.specimenID, scenario: scenario, controls: column.controls)
    }

    func redlines(_ column: StageColumn, scenario: String) -> [StageRedline] {
        provider.redlines(id: column.specimenID, scenario: scenario, controls: column.controls)
    }

    /// The longest motion among the columns on screen, or nil when everything is still.
    var motionDuration: Double? {
        if state.mode == .matrix { return nil }
        var longest: Double? = nil
        for c in visibleColumns {
            if let d = provider.motionDuration(id: c.specimenID, scenario: state.scenario, controls: c.controls) {
                longest = max(longest ?? 0, d)
            }
        }
        return longest
    }

    /// The columns the current mode draws.
    var visibleColumns: [StageColumn] {
        let all = columns
        switch state.mode {
        case .side:
            if StageColumns.usesFilmstrip(columnCount: all.count) {
                var out: [StageColumn] = []
                if let t = all.first(where: { $0.isToday }) { out.append(t) }
                if let s = selectedColumn { out.append(s) }
                return out
            }
            return all
        case .overlay, .flip, .wipe:
            var out: [StageColumn] = []
            if let t = all.first(where: { $0.isToday }) { out.append(t) }
            if let s = selectedColumn { out.append(s) }
            return out
        case .matrix:
            return all
        }
    }

    func motionMarks() -> [StageMotionMark] {
        let column = selectedColumn ?? columns.first
        guard let c = column else { return [] }
        return provider.motionMarks(id: c.specimenID, scenario: state.scenario, controls: c.controls)
    }

    // MARK: Pins

    func beginPin(option: String?, x: Double, y: Double) {
        pinDraft = StagePinDraft(option: option, x: x, y: y)
        pinDraftText = ""
    }

    func commitPinDraft() {
        guard let d = pinDraft else { return }
        send(.addPin(text: pinDraftText, option: d.option, x: d.x, y: d.y))
        pinDraft = nil
        pinDraftText = ""
    }

    func cancelPinDraft() {
        pinDraft = nil
        pinDraftText = ""
        if state.pinMode { send(.togglePinMode) }
    }

    /// Tells the agent a specimen failed to draw (decision H21).
    func reportFailure(_ column: StageColumn) {
        let body = "Specimen \"\(column.title)\" (\(column.specimenID)) did not draw on the Stage. "
            + StageReducer.describe(state, manifest: manifest)
        send(.setAskDraft(body))
        send(.sendAsk)
    }
}
