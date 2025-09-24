import SwiftUI

struct SidebarView: View {
    @Binding var connections: [SavedConnection]
    @Binding var selectedConnectionID: UUID?
    @Binding var databaseStructure: [String: DatabaseStructure]
    @EnvironmentObject var appModel: AppModel
    var onAddConnection: () -> Void
    var onDeleteConnection: (UUID) -> Void
    
    var body: some View {
        SidebarMenu(
            connections: connections,
            selectedConnectionID: $selectedConnectionID,
            databaseStructure: databaseStructure,
            onAddConnection: onAddConnection,
            onDeleteConnection: onDeleteConnection
        )
        .environmentObject(appModel)
       /* .background {
            // Use the proper liquid glass background
            Rectangle()
                .fill(.clear)
        }
        */
    
    }
}
