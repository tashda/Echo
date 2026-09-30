import SwiftUI

struct LabRootView: View {
    @State private var store = LabStore()
    @State private var selection: String? = LabRegistry.pages.first?.id
    @State private var showsFeedback = true

    var body: some View {
        NavigationSplitView {
            LabSidebar(selection: $selection)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        } detail: {
            if let page = LabRegistry.page(id: selection) {
                LabPageContainer(page: page)
                    .inspector(isPresented: $showsFeedback) {
                        LabFeedbackInspector(page: page)
                            .inspectorColumnWidth(min: 260, ideal: 320, max: 420)
                    }
                    .toolbar {
                        ToolbarItem {
                            Button("Feedback", systemImage: "sidebar.trailing") { showsFeedback.toggle() }
                        }
                    }
            } else {
                ContentUnavailableView("Choose a page", systemImage: "sidebar.left")
            }
        }
        .environment(store)
    }
}
