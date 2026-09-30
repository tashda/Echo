import SwiftUI

struct LabRootView: View {
    @State private var store = LabStore()
    @State private var destination: LabDestination? = .area("explorer-tree")
    @State private var currentPageID: String?
    @State private var openRound: String?
    @State private var showsFeedback = false

    var body: some View {
        NavigationSplitView {
            LabSidebar(selection: $destination)
                .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 300)
        } detail: {
            detail
                .inspector(isPresented: $showsFeedback) {
                    if let page = LabRegistry.page(id: currentPageID) {
                        LabFeedbackInspector(page: page)
                            .inspectorColumnWidth(min: 260, ideal: 320, max: 420)
                    } else {
                        ContentUnavailableView("Feedback", systemImage: "text.bubble",
                                               description: Text("Open a page to give feedback on it."))
                            .inspectorColumnWidth(min: 260, ideal: 320, max: 420)
                    }
                }
                .toolbar {
                    ToolbarItem {
                        Button("Feedback", systemImage: "sidebar.trailing") { showsFeedback.toggle() }
                    }
                }
        }
        .environment(store)
        .onChange(of: destination) { _, new in
            switch new {
            case .area(let id): currentPageID = LabAreas.area(id: id)?.asBuiltPageID
            case .page(let id): currentPageID = id
            default: currentPageID = nil
            }
        }
        .onAppear { currentPageID = LabAreas.area(id: "explorer-tree")?.asBuiltPageID }
    }

    @ViewBuilder
    private var detail: some View {
        switch destination {
        case .inbox:
            LabInboxView { pageID in
                if let areaID = LabAreas.areaID(ofPage: pageID) {
                    destination = .area(areaID)
                    openRound = pageID.hasPrefix("asbuilt.") ? nil : pageID
                } else {
                    destination = .page(pageID)
                }
            }
        case .area(let id):
            if let area = LabAreas.area(id: id) {
                LabAreaView(area: area, currentPageID: $currentPageID, openRound: $openRound)
                    .id(area.id)
            }
        case .page(let id):
            if let page = LabRegistry.page(id: id) { LabPageContainer(page: page) }
        case nil:
            ContentUnavailableView("Choose a page", systemImage: "sidebar.left")
        }
    }
}
