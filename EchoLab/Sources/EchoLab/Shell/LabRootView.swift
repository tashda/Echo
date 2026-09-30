import SwiftUI

struct LabRootView: View {
    @State private var store = LabStore()
    @State private var navigator = LabNavigator(start: LabLocation(destination: .area("explorer-tree")))
    @State private var showsFeedback = false
    @State private var feedbackElement: (id: String, name: String)?

    private var location: LabLocation { navigator.current }

    /// The page the Feedback panel is about.
    private var currentPageID: String? {
        switch location.destination {
        case .area(let id): location.round ?? LabAreas.area(id: id)?.asBuiltPageID
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
                .inspector(isPresented: $showsFeedback) {
                    Group {
                        if let page = LabRegistry.page(id: currentPageID) {
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
                    ToolbarItem {
                        Button("Feedback", systemImage: "sidebar.trailing") { showsFeedback.toggle() }
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
        .onAppear {
            // Launch straight onto a page: ECHOLAB_PAGE=<LabPage.id> (used for testing).
            // "area:<id>:<overview|spec|rounds>" opens an area on that tab.
            if let id = ProcessInfo.processInfo.environment["ECHOLAB_PAGE"] {
                let parts = id.split(separator: ":").map(String.init)
                if parts.count == 3, parts[0] == "area" {
                    navigator.go(LabLocation(destination: .area(parts[1]), tab: LabAreaTab(rawValue: parts[2].capitalized) ?? .overview))
                } else { navigator.openPage(id) }
            }
        }
    }

    private var title: String {
        switch location.destination {
        case .inbox: "Inbox"
        case .rounds: "Rounds"
        case .area(let id): LabAreas.area(id: id)?.title ?? ""
        case .page(let id): LabRegistry.page(id: id)?.title ?? ""
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch location.destination {
        case .inbox: LabInboxView()
        case .rounds: LabRoundsIndexView()
        case .area(let id):
            if let area = LabAreas.area(id: id) { LabAreaView(area: area, location: location) }
        case .page(let id):
            if let page = LabRegistry.page(id: id) { LabPageContainer(page: page) }
        }
    }
}
