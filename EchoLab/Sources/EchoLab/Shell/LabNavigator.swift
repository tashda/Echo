import Observation

enum LabAreaTab: String, CaseIterable, Identifiable, Codable {
    case overview = "Overview", spec = "Spec", rounds = "Rounds"
    var id: String { rawValue }
}

/// Where you are: a destination, and inside an area which view and which round page is open.
struct LabLocation: Hashable, Codable {
    var destination: LabDestination
    var tab: LabAreaTab = .overview
    /// A round page opened inside the area (`LabPage.id`).
    var round: String?
}

/// One history for the whole lab, so Back always returns to where you were before, whether
/// that was the Inbox, the Rounds list, another area or another tab of the same area.
@Observable @MainActor
final class LabNavigator {
    private struct Saved: Codable { var stack: [LabLocation]; var index: Int }

    private(set) var stack: [LabLocation]
    private(set) var index = 0

    /// Starts where you left off (history included), or at `start`.
    init(start: LabLocation) {
        if let saved: Saved = LabPrefs.load("navigation", default: Optional<Saved>.none),
           !saved.stack.isEmpty, saved.stack.indices.contains(saved.index),
           saved.stack.allSatisfy(Self.isValid) {
            stack = saved.stack
            index = saved.index
        } else {
            stack = [start]
        }
    }

    private static func isValid(_ location: LabLocation) -> Bool {
        switch location.destination {
        case .inbox, .rounds, .spec: true
        case .area(let id): LabAreas.area(id: id) != nil && (location.round.map { LabRegistry.page(id: $0) != nil } ?? true)
        case .page(let id): LabRegistry.page(id: id) != nil
        }
    }

    private func persist() { LabPrefs.save(Saved(stack: stack, index: index), key: "navigation") }

    var current: LabLocation { stack[index] }
    var canGoBack: Bool { index > 0 }
    var canGoForward: Bool { index < stack.count - 1 }

    func go(_ location: LabLocation) {
        guard location != current else { return }
        stack.removeSubrange((index + 1)...)
        stack.append(location)
        if stack.count > 60 { stack.removeFirst(stack.count - 60) }
        index = stack.count - 1
        persist()
    }

    func back() { if canGoBack { index -= 1; persist() } }
    func forward() { if canGoForward { index += 1; persist() } }

    func show(_ destination: LabDestination) { go(LabLocation(destination: destination)) }

    func setTab(_ tab: LabAreaTab) {
        var next = current
        next.tab = tab
        next.round = nil
        go(next)
    }

    /// Opens a round (or As built) page in its own area; on its own when it has none.
    func openPage(_ pageID: String) {
        guard let areaID = LabAreas.areaID(ofPage: pageID) else {
            go(LabLocation(destination: .page(pageID)))
            return
        }
        let isAsBuilt = pageID.hasPrefix("asbuilt.")
        go(LabLocation(destination: .area(areaID), tab: isAsBuilt ? .overview : .rounds, round: isAsBuilt ? nil : pageID))
    }
}
