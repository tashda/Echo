import SwiftUI

struct MySQLBackupSheetContainer: View {
    @Binding var isPresented: Bool
    @State private var viewModel: MySQLBackupRestoreViewModel

    init(connection: SavedConnection, session: DatabaseSession, databaseName: String, isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        let authConfig = AppDirector.shared.identityRepository.resolveAuthenticationConfiguration(for: connection, overridePassword: nil)
        let vm = MySQLBackupRestoreViewModel(
            connection: connection,
            session: session,
            databaseName: databaseName,
            password: authConfig?.password,
            resolvedUsername: authConfig?.username
        )
        vm.activityEngine = AppDirector.shared.activityEngine
        vm.notificationEngine = AppDirector.shared.notificationEngine
        self._viewModel = State(initialValue: vm)
    }

    var body: some View {
        MySQLBackupSidebarSheet(
            viewModel: viewModel,
            customToolPath: nil,
            onDismiss: { isPresented = false }
        )
    }
}

struct MySQLRestoreSheetContainer: View {
    let connectionSession: ConnectionSession?
    @Binding var isPresented: Bool
    @State private var viewModel: MySQLBackupRestoreViewModel
    @Environment(EnvironmentState.self) private var environmentState
    private let databaseName: String

    init(connection: SavedConnection, session: DatabaseSession, databaseName: String, connectionSession: ConnectionSession?, isPresented: Binding<Bool>) {
        self.connectionSession = connectionSession
        self._isPresented = isPresented
        self.databaseName = databaseName
        let authConfig = AppDirector.shared.identityRepository.resolveAuthenticationConfiguration(for: connection, overridePassword: nil)
        let vm = MySQLBackupRestoreViewModel(
            connection: connection,
            session: session,
            databaseName: databaseName,
            password: authConfig?.password,
            resolvedUsername: authConfig?.username
        )
        vm.activityEngine = AppDirector.shared.activityEngine
        vm.notificationEngine = AppDirector.shared.notificationEngine
        self._viewModel = State(initialValue: vm)
    }

    var body: some View {
        MySQLRestoreSidebarSheet(
            viewModel: viewModel,
            customToolPath: nil,
            onDismiss: { isPresented = false }
        )
        .onChange(of: viewModel.restorePhase) { _, phase in
            if case .completed = phase, let connectionSession {
                Task {
                    await environmentState.loadSchemaForDatabase(databaseName, connectionSession: connectionSession)
                }
            }
        }
    }
}
