import SwiftUI

/// Start disposable database servers from echo-server-lab recipes, see what runs on the lab host,
/// and watch builds. The same `ServerLab` API the `.server(...)` test trait uses.
struct ServersTestPage: View {
    @State private var model = LabServersModel.shared
    @AppStorage("lab.servers.recipe") private var selectedRecipe: String?
    @AppStorage("lab.servers.leaseMinutes") private var leaseMinutes = 60

    var body: some View {
        if let error = model.loadError {
            ContentUnavailableView(
                "The lab is not available",
                systemImage: "server.rack",
                description: Text(error)
            )
        } else {
            HSplitView {
                ServerRecipeList(model: model, selectedRecipe: $selectedRecipe, leaseMinutes: $leaseMinutes)
                    .frame(minWidth: 320, idealWidth: 380, maxWidth: 480)
                RunningServersPanel(model: model)
                    .frame(minWidth: 480)
            }
            .task {
                // Keep the running list current while the page is open.
                while !Task.isCancelled {
                    await model.refresh()
                    try? await Task.sleep(for: .seconds(5))
                }
            }
        }
    }
}
