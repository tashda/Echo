import SwiftUI

struct MaintenanceView: View {
    @Bindable var viewModel: MaintenanceViewModel

    var body: some View {
        switch viewModel.databaseType {
        case .postgresql:
            PostgresMaintenanceView(viewModel: viewModel)
        case .microsoftSQL:
            MSSQLMaintenanceView()
        default:
            EmptyStatePlaceholder(
                icon: "wrench.and.screwdriver",
                title: "Maintenance",
                subtitle: "Maintenance is not available for this database type"
            )
        }
    }
}
