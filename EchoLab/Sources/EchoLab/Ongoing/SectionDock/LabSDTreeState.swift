import SwiftUI

/// Scroll position and viewport, read only by the cards layer and the header wash, so scrolling
/// never re-renders the rows (as Echo's `ExplorerTreeScrollState`).
@Observable @MainActor
final class LabSDScroll {
    var offset: CGFloat = 0
    var viewport: CGFloat = 0
}

/// One tree's live state: the section each server shows, open folders, collapsed servers, what
/// has loaded, and scrolling requests.
@Observable @MainActor
final class LabSDTreeState {
    /// The section each server's dock has chosen ("more" for M2's More section).
    var chosen: [String: String] = [:]
    var expanded: Set<String> = []
    var collapsed: Set<String> = []
    var loaded: Set<String> = []
    var loading: Set<String> = []
    var selectedRowID: String?
    /// S3: each server's rows' opacity while they fade through.
    var bodyOpacity: [String: Double] = [:]
    /// S4: whether the last switch moved right in the dock.
    var movedForward: [String: Bool] = [:]
    /// N2: the list never gets shorter than this until you scroll up.
    var heldHeight: CGFloat = 0
    /// Where each section was scrolled to, for Glide and Jump.
    var anchors: [String: CGFloat] = [:]
    /// A scroll the view should make: where, and with which animation (nil: instantly).
    var scrollRequest: (y: CGFloat, animation: Animation?)?
    var scrollRequestID = 0

    static let moreID = "more"
    static let latency: Duration = .milliseconds(900)

    func chosenSection(_ server: LabSDServer) -> String { chosen[server.id] ?? server.sections.first?.id ?? "" }
    func key(_ server: LabSDServer, _ sectionID: String) -> String { "\(server.id)|\(sectionID)" }
    func isLoading(_ server: LabSDServer, _ sectionID: String) -> Bool { loading.contains(key(server, sectionID)) }

    // MARK: - Switching

    /// Chooses a section the way the switching option says. `serverTop` is where the server's
    /// name sits in the list, for Glide.
    func choose(_ sectionID: String, in server: LabSDServer, options: LabSDOptions, motion: EchoMotion,
                scroll: LabSDScroll, serverTop: CGFloat) {
        let current = chosenSection(server)
        guard sectionID != current else { return }
        anchors[key(server, current)] = scroll.offset
        if options.neighbours == .holdPosition { heldHeight = max(heldHeight, scroll.offset + scroll.viewport) }

        let order = server.sections.map(\.id) + [Self.moreID]
        let forward = (order.firstIndex(of: sectionID) ?? 0) > (order.firstIndex(of: current) ?? 0)
        let needsLoad = server.section(sectionID)?.loadsOnOpen == true && !loaded.contains(key(server, sectionID))
        let apply = {
            self.chosen[server.id] = sectionID
            self.movedForward[server.id] = forward
            if needsLoad { self.loading.insert(self.key(server, sectionID)) }
        }

        switch options.switchMotion {
        case .today:
            // Echo sets the selection plainly; the list's own animation modifiers animate it.
            apply()
        case .cardCrossfade, .slide, .swapAndSettle:
            withAnimation(motion.settle) { apply() }
        case .fadeThrough:
            withAnimation(.easeIn(duration: 0.08 * motion.durationScale)) { bodyOpacity[server.id] = 0 }
            Task(name: "lab-section-dock-fade") {
                try? await Task.sleep(for: .milliseconds(Int(80 * motion.durationScale)))
                withAnimation(motion.settle) { apply() }
                withAnimation(.easeOut(duration: 0.18 * motion.durationScale)) { self.bodyOpacity[server.id] = 1 }
            }
        case .instant:
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { apply() }
        }

        switch options.switchScroll {
        case .today:
            request(y: anchors[key(server, sectionID)] ?? serverTop, animation: motion.reveal)
        case .jump:
            if let anchor = anchors[key(server, sectionID)] { request(y: anchor, animation: nil) }
        case .stay:
            break
        }
        if needsLoad { finishLoading(key(server, sectionID), motion: motion) }
    }

    func toggleFolder(_ node: LabSDNode, motion: EchoMotion) {
        selectedRowID = node.id
        withAnimation(motion.expand) {
            if expanded.contains(node.id) { expanded.remove(node.id) } else { expanded.insert(node.id) }
        }
    }

    func toggleServer(_ server: LabSDServer, motion: EchoMotion, scroll: LabSDScroll, neighbours: LabSDNeighbours) {
        if neighbours == .holdPosition { heldHeight = max(heldHeight, scroll.offset + scroll.viewport) }
        withAnimation(motion.expand) {
            if collapsed.contains(server.id) { collapsed.remove(server.id) } else { collapsed.insert(server.id) }
        }
    }

    /// N2: the held room shrinks as you scroll up, so it never shows as an empty jump.
    func scrolled(to offset: CGFloat, viewport: CGFloat) {
        guard heldHeight > 0 else { return }
        heldHeight = offset + viewport < heldHeight ? offset + viewport : heldHeight
    }

    func request(y: CGFloat, animation: Animation?) {
        scrollRequest = (y, animation)
        scrollRequestID += 1
    }

    /// Forgets what has loaded, which sections are chosen and what is open.
    func reset() {
        chosen = [:]
        expanded = []
        collapsed = []
        loaded = []
        loading = []
        selectedRowID = nil
        bodyOpacity = [:]
        heldHeight = 0
        anchors = [:]
    }

    private func finishLoading(_ key: String, motion: EchoMotion) {
        Task(name: "lab-section-dock-load") {
            try? await Task.sleep(for: Self.latency)
            withAnimation(motion.settle) {
                self.loading.remove(key)
                self.loaded.insert(key)
            }
        }
    }
}
