import SwiftUI

struct LabRootView: View {
    @State private var selection: String? = LabRegistry.pages.first?.id

    var body: some View {
        NavigationSplitView {
            LabSidebar(selection: $selection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            if let page = LabRegistry.page(id: selection) {
                LabPageContainer(page: page)
            } else {
                ContentUnavailableView("Choose a page", systemImage: "sidebar.left")
            }
        }
    }
}
