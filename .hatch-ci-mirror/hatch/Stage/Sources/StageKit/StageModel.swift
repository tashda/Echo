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
    /// The Proposal as the owner sees it: the latest revision, or an earlier one chosen in the revision switcher (decision H15).
    @Published public private(set) var manifest: StageManifest
    @Published public private(set) var state: StageState
    /// The latest revision Hatch gave this Stage.
    @Published public private(set) var latestManifest: StageManifest
    /// One-line summaries of the revisions, from Hatch.
    @Published public private(set) var revisionSummaries: [Int: String] = [:]
    /// Set when a heartbeat says Hatch has a newer revision than the one on screen (decision S5: the Reload button).
    @Published public private(set) var reloadAvailable: Int? = nil
    /// true while a reload is running.
    @Published public private(set) var reloading: Bool = false
    @Published var pinDraft: StagePinDraft? = nil
    @Published var pinDraftText: String = ""
    /// A problem worth showing: Hatch is away, or something was refused.
    @Published public private(set) var notice: String? = nil
    /// Writes waiting for Hatch (decision S7).
    @Published public private(set) var pendingWrites: Int = 0

    public let provider: any SpecimenProvider
    let dataSource: StageDataSource
    /// The revision this Stage was started with. The specimens are compiled into the app, so a manifest newer than this means
    /// the app may not know every specimen (decision H21: say that a specimen is older than the latest code).
    public let launchRevision: Int
    /// Takes the picture sent with a question (decision H14). The Stage app sets it to a window snapshot; tests leave it nil.
    public var captureView: (@MainActor () -> Data?)? = nil
    private var persistTask: Task<Void, Never>? = nil
    private var effectChain: Task<Void, Never>? = nil
    private var heartbeatTask: Task<Void, Never>? = nil

    public init(manifest: StageManifest, provider: any SpecimenProvider, dataSource: StageDataSource, state: StageState? = nil) {
        self.latestManifest = manifest
        self.launchRevision = manifest.revision
        self.provider = provider
        self.dataSource = dataSource
        var initial = state ?? StageState(manifest: manifest)
        let viewed = StageReducer.viewedManifest(full: manifest, state: initial)
        StageReducer.reconcile(&initial, manifest: viewed)
        self.manifest = viewed
        self.state = initial
    }


    // MARK: Actions

    public func send(_ action: StageAction) {
        var next = state
        let result = StageReducer.apply(&next, action, full: latestManifest)
        // The viewed manifest only changes when the owner switches revision (it is compared there, not on every motion tick).
        if next.viewRevision != state.viewRevision { manifest = result.viewed }
        if next != state { state = next }
        perform(result.effects)
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

    /// Loads what was remembered for this ticket, then lays Hatch's copy over it (pins and notes too), and starts the heartbeat.
    /// Called once when the window appears.
    public func restore() async {
        do {
            if var saved = try await dataSource.loadState() {
                StageReducer.reconcile(&saved, manifest: StageReducer.viewedManifest(full: latestManifest, state: saved))
                state = saved
                manifest = StageReducer.viewedManifest(full: latestManifest, state: saved)
            }
        } catch {
            notice = "Could not load your earlier settings: \(error)"
        }
        await mergeFromHatch()
        pendingWrites = await dataSource.pendingCount()
        startHeartbeat()
    }

    /// Hatch is the only writer, so its copy of the answers wins unless writes are still waiting to be delivered.
    private func mergeFromHatch() async {
        guard let snapshot = await dataSource.loadSnapshot() else { return }
        let waiting = await dataSource.pendingCount()
        var next = state
        StageMerge.apply(snapshot, to: &next, manifest: latestManifest, hasPendingWrites: waiting > 0)
        if next != state { state = next }
        revisionSummaries = snapshot.revisionSummaries
    }

    /// Reads the Proposal again from Hatch: the Reload button and the answer to "a new revision is ready" (decision S5).
    public func reload() async {
        reloading = true
        defer { reloading = false }
        do {
            let fresh = try await dataSource.loadManifest()
            var next = state
            latestManifest = fresh
            let viewed = StageReducer.viewedManifest(full: fresh, state: next)
            if let n = next.viewRevision, n >= fresh.revision { next.viewRevision = nil }
            StageReducer.reconcile(&next, manifest: viewed)
            manifest = viewed
            state = next
            reloadAvailable = nil
            notice = nil
            await mergeFromHatch()
        } catch {
            notice = "Could not reload: \(error)"
        }
    }

    // MARK: Heartbeat (decisions S5, S7)

    /// Tells Hatch every few seconds that this Stage is alive and which revision it shows. Hatch shows "Stage closed unexpectedly"
    /// when the beats stop without a "closed". The reply says whether a newer revision waits.
    func startHeartbeat() {
        guard heartbeatTask == nil else { return }
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.beat(state: "running")
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    func beat(state word: String) async {
        let shown = latestManifest.revision
        let reply = await dataSource.heartbeat(revision: shown, state: word)
        if let reply, reply.reload, reply.latestRevision > shown {
            if reloadAvailable != reply.latestRevision { reloadAvailable = reply.latestRevision }
        }
        let waiting = await dataSource.pendingCount()
        if waiting != pendingWrites { pendingWrites = waiting }
    }

    /// Called when the window closes, so Hatch can tell a closed Stage from a crashed one.
    public func announceClosed() async {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        _ = await dataSource.heartbeat(revision: latestManifest.revision, state: "closed")
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
        // The picture is taken now, while the stage still looks the way the owner asked about it.
        let picture: Data? = effects.contains(where: { if case .note(let kind, _) = $0 { return kind == "ask" } else { return false } })
            ? captureView?() : nil
        let source = dataSource
        let previous = effectChain
        effectChain = Task { [weak self] in
            await previous?.value
            for effect in effects {
                do {
                    let delivery = try await source.perform(effect, screenshot: picture)
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

    /// The revisions the switcher offers, newest first.
    var revisionNumbers: [Int] { Array((1...max(latestManifest.revision, 1)).reversed()) }

    var isViewingEarlierRevision: Bool { manifest.revision < latestManifest.revision }

    /// true when Hatch's manifest is newer than the code this app was built from: a specimen added since may be missing here.
    var manifestIsNewerThanApp: Bool { latestManifest.revision > launchRevision }

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
            if StageColumns.usesFilmstrip(columns: all) {
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
