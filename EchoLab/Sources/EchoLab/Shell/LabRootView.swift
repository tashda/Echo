import SwiftUI

struct LabRootView: View {
    @State private var store = LabStore()
    @State private var navigator = LabNavigator(start: LabLocation(destination: .spec))
    @AppStorage("lab.showsFeedback") private var showsFeedback = false
    @State private var feedbackElement: (id: String, name: String)?

    private var location: LabLocation { navigator.current }

    /// The page the Feedback panel is about.
    private var currentPageID: String? {
        switch location.destination {
        case .area(let id): location.round ?? LabAreas.area(id: id)?.asBuiltPageID
        case .spec: LabSpecState.shared.area(forSelection: LabSpecState.shared.selected)?.asBuiltPageID
        case .page(let id): id
        default: nil
        }
    }

    var body: some View {
        NavigationSplitView {
            LabSidebar(selection: Binding(
                get: { location.destination },
                set: { if let new = $0 { navigator.show(new) } }))
                .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 300)
        } detail: {
            detail
                .navigationTitle(title)
                .navigationSubtitle(subtitle)
                .inspector(isPresented: $showsFeedback) {
                    Group {
                        if let page = LabRegistry.page(id: currentPageID), let decision = page.decision {
                            RoundDecisionPanel(page: page, decision: decision())
                        } else if let page = LabRegistry.page(id: currentPageID) {
                            LabFeedbackInspector(page: page, element: $feedbackElement)
                        } else {
                            ContentUnavailableView("Feedback", systemImage: "text.bubble",
                                                   description: Text("Open a page to give feedback on it."))
                        }
                    }
                    .inspectorColumnWidth(min: 260, ideal: 320, max: 420)
                }
                .toolbar {
                    ToolbarItemGroup(placement: .navigation) {
                        Button("Back", systemImage: "chevron.backward") { navigator.back() }
                            .disabled(!navigator.canGoBack).keyboardShortcut("[", modifiers: .command)
                        Button("Forward", systemImage: "chevron.forward") { navigator.forward() }
                            .disabled(!navigator.canGoForward).keyboardShortcut("]", modifiers: .command)
                    }
                    ToolbarItem { LabBuildStatus(builder: .shared) }
                    ToolbarItem { LabZoomControls(zoom: .shared) }
                    ToolbarItem {
                        Button(LabRegistry.page(id: currentPageID)?.decision != nil ? "Decision" : "Feedback", systemImage: "sidebar.trailing") { showsFeedback.toggle() }
                    }
                }
        }
        .environment(store)
        .environment(navigator)
        .environment(\.labOpenRound) { navigator.openPage($0) }
        .environment(\.labGiveFeedback) { id, name in
            feedbackElement = (id, name)
            showsFeedback = true
        }
        .onChange(of: location.destination) { _, new in
            // Spec, Inbox and Rounds have nothing to give feedback on; the panel opens from a page or "Feedback on <ID>".
            if new == .spec || new == .inbox || new == .rounds { showsFeedback = false }
        }
        .onChange(of: currentPageID) { _, new in
            // Round pages keep their decision panel open.
            if let page = LabRegistry.page(id: new), page.decision != nil { showsFeedback = true }
        }
        .onAppear {
            LabBuilder.shared.startWatching()
            FastRoundStore.shared.startWatching()
            if ProcessInfo.processInfo.environment["ECHOLAB_ACTION"] == "rebuild" { LabBuilder.shared.rebuild() }   // for testing
            // A rebuild waits for you when the page you're on has picks that aren't sent yet.
            LabBuilder.shared.shouldAskBeforeRelaunch = { [store, navigator] in
                guard let page = LabRegistry.page(id: { if case .page(let id) = navigator.current.destination { id } else { navigator.current.round }}()),
                      page.decision != nil, store.status(of: page) == .judging else { return false }
                return page.decision.map { !($0().topics.allSatisfy { store.pick(page, topic: $0.id) == nil }) } ?? false
            }
            // Launch straight onto a page: ECHOLAB_PAGE=<LabPage.id> (used for testing).
            // "area:<id>:<overview|spec|rounds>" opens an area on that tab.
            if let id = ProcessInfo.processInfo.environment["ECHOLAB_PAGE"] {
                let parts = id.split(separator: ":").map(String.init)
                if id == "inbox" { navigator.show(.inbox) }
                else if id == "rounds" { navigator.show(.rounds) }
                else if parts.first == "spec", parts.count == 2 {
                    LabSpecState.shared.select(parts[1])
                    navigator.go(LabLocation(destination: .spec))
                } else if parts.count == 3, parts[0] == "area" {
                    navigator.go(LabLocation(destination: .area(parts[1]), tab: LabAreaTab(rawValue: parts[2].capitalized) ?? .overview))
                } else { navigator.openPage(id) }
            }
        }
    }

    /// The path, in the toolbar: where you are inside the area.
    private var subtitle: String {
        guard case .area = location.destination else { return "" }
        if let round = location.round, let page = LabRegistry.page(id: round) { return "Rounds › \(page.title)" }
        return location.tab.rawValue
    }

    private var title: String {
        switch location.destination {
        case .inbox: "Inbox"
        case .rounds: "Rounds"
        case .spec: "Spec"
        case .area(let id): LabAreas.area(id: id)?.title ?? ""
        case .page(let id): LabRegistry.page(id: id).map { $0.section == .test ? "Test" : $0.section.rawValue } ?? ""
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch location.destination {
        case .inbox: LabInboxView()
        case .rounds: LabRoundsIndexView()
        case .spec: LabSpecPage()
        case .area(let id):
            if let area = LabAreas.area(id: id) { LabAreaView(area: area, location: location) }
        case .page(let id):
            if let page = LabRegistry.page(id: id) { LabPageContainer(page: page) }
        }
    }
}
