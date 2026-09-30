import SwiftUI

/// The playground's live state: which section each card shows, which folders are open (kept per
/// section), what has loaded, and which icons each dock shows (per database type, or per server).
@Observable @MainActor
final class LabSCState {
    /// The section each server's dock has chosen.
    var chosen: [String: String] = [:]
    /// The section each card is drawing. Differs from `chosen` only while Keep + spinner waits.
    var shown: [String: String] = [:]
    /// Whether the last switch moved right in the dock, for the slide.
    var movedForward: [String: Bool] = [:]
    /// Open folders, per server and section, so coming back to a section finds them as left.
    var expanded: [String: Set<String>] = [:]
    var loaded: Set<String> = []
    var loading: Set<String> = []
    var selectedRowID: String?

    var typeDocks: [LabSCEngine: [String]] = Dictionary(uniqueKeysWithValues: LabSCEngine.allCases.map { ($0, LabSCDefaults.dock(for: $0)) })
    var serverDocks: [String: [String]] = [:]

    // MARK: - Docks

    func dock(for server: LabSCServer) -> [String] {
        (serverDocks[server.id] ?? typeDocks[server.engine] ?? []).filter { server.section($0) != nil }
    }

    /// Sections not in the dock; More lists them so nothing is ever out of reach.
    func overflow(for server: LabSCServer) -> [LabSCSection] {
        let dock = dock(for: server)
        return server.sections.filter { !dock.contains($0.id) }
    }

    func setDock(_ ids: [String], for server: LabSCServer, onlyThisServer: Bool) {
        if onlyThisServer {
            serverDocks[server.id] = ids
        } else {
            typeDocks[server.engine] = ids
            serverDocks[server.id] = nil
        }
    }

    func toggle(_ sectionID: String, in server: LabSCServer) {
        var ids = dock(for: server)
        if let index = ids.firstIndex(of: sectionID) {
            guard ids.count > 1 else { return }
            ids.remove(at: index)
        } else {
            ids.append(sectionID)
        }
        setDock(ids, for: server, onlyThisServer: true)
    }

    func resetDock(for server: LabSCServer) {
        serverDocks[server.id] = nil
        typeDocks[server.engine] = LabSCDefaults.dock(for: server.engine)
    }

    // MARK: - Sections

    func chosenSection(of server: LabSCServer) -> String { chosen[server.id] ?? "databases" }
    func shownSection(of server: LabSCServer) -> String { shown[server.id] ?? chosenSection(of: server) }

    func sectionKey(_ server: LabSCServer, _ sectionID: String) -> String { "\(server.id)|\(sectionID)" }

    func isLoaded(_ key: String) -> Bool { loaded.contains(key) }

    func expandedIDs(_ server: LabSCServer, _ section: LabSCSection) -> Set<String> {
        expanded[sectionKey(server, section.id)] ?? section.initiallyExpanded
    }

    /// Chooses a section; loads it first if it hasn't been opened yet.
    func choose(_ sectionID: String, in server: LabSCServer, options: LabSCOptions, animation: Animation) {
        let current = chosenSection(of: server)
        guard sectionID != current, let section = server.section(sectionID) else { return }
        let order = server.sections.map(\.id)
        let forward = (order.firstIndex(of: sectionID) ?? 0) > (order.firstIndex(of: current) ?? 0)
        let key = sectionKey(server, sectionID)
        let needsLoad = section.loadsOnOpen && !loaded.contains(key)

        withAnimation(options.switchMotion == .instant ? nil : animation) {
            chosen[server.id] = sectionID
            movedForward[server.id] = forward
            if !(needsLoad && options.loading == .keep) { shown[server.id] = sectionID }
            if needsLoad { loading.insert(key) }
        }
        guard needsLoad else { return }
        finishLoading(key, after: options.latency, animation: animation) { [weak self] in
            self?.shown[server.id] = self?.chosen[server.id]
        }
    }

    /// Opens or closes a folder; a folder that loads on open fetches its items first.
    func toggleFolder(_ node: LabSCNode, server: LabSCServer, section: LabSCSection, options: LabSCOptions, animation: Animation) {
        let key = sectionKey(server, section.id)
        var ids = expandedIDs(server, section)
        selectedRowID = node.id
        if ids.contains(node.id) {
            ids.remove(node.id)
            withAnimation(animation) { expanded[key] = ids }
            return
        }
        let needsLoad = node.loadsOnOpen && !loaded.contains(node.id)
        ids.insert(node.id)
        if needsLoad && options.loading == .keep {
            // The folder stays closed with a spinner in its count slot, then opens once.
            loading.insert(node.id)
            finishLoading(node.id, after: options.latency, animation: animation) { [weak self] in
                self?.expanded[key] = ids
            }
            return
        }
        withAnimation(animation) {
            expanded[key] = ids
            if needsLoad { loading.insert(node.id) }
        }
        if needsLoad { finishLoading(node.id, after: options.latency, animation: animation) {} }
    }

    /// Clears what has loaded, so loading can be judged again.
    func reset() {
        loaded = []
        loading = []
        shown = [:]
        chosen = [:]
        expanded = [:]
        selectedRowID = nil
    }

    private func finishLoading(_ key: String, after latency: LabSCLatency, animation: Animation, then: @escaping @MainActor () -> Void) {
        Task(name: "lab-server-card-load") { [weak self] in
            try? await Task.sleep(for: latency.duration)
            guard let self else { return }
            withAnimation(animation) {
                self.loading.remove(key)
                self.loaded.insert(key)
                then()
            }
        }
    }
}
