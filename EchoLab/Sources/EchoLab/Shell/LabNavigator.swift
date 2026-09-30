import Observation

enum LabAreaTab: String, CaseIterable, Identifiable {
    case overview = "Overview", spec = "Spec", rounds = "Rounds"
    var id: String { rawValue }
}

/// Where you are: a destination, and inside an area which view and which round page is open.
struct LabLocation: Hashable {
    var destination: LabDestination
    var tab: LabAreaTab = .overview
    /// A round page opened inside the area (`LabPage.id`).
    var round: String?
}

/// One history for the whole lab, so Back always returns to where you were before, whether
/// that was the Inbox, the Rounds list, another area or another tab of the same area.
@Observable @MainActor
final class LabNavigator {
    private(set) var stack: [LabLocation]
    private(set) var index = 0

    init(start: LabLocation) { stack = [start] }

    var current: LabLocation { stack[index] }
    var canGoBack: Bool { index > 0 }
    var canGoForward: Bool { index < stack.count - 1 }

    func go(_ location: LabLocation) {
        guard location != current else { return }
        stack.removeSubrange((index + 1)...)
        stack.append(location)
        index = stack.count - 1
    }

    func back() { if canGoBack { index -= 1 } }
    func forward() { if canGoForward { index += 1 } }

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
