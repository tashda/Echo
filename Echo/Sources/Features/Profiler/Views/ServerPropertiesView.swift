import SwiftUI

struct ServerPropertiesView: View {
    @Bindable var viewModel: ServerPropertiesViewModel
    
    var body: some View {
        ContentUnavailableView {
            Label("Server Properties", systemImage: "gearshape.2")
        } description: {
            Text("Server-level properties and configuration are coming soon.")
        }
        .background(ColorTokens.Background.primary)
    }
}
