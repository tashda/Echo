import SwiftUI

struct DatabaseSidebarView: View {
    @Binding var selectedConnectionID: UUID?
    let icon: String
    let title: String
    let description: String

    var body: some View {
        AgentSidebarView(selectedConnectionID: $selectedConnectionID)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
