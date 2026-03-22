import SwiftUI

struct PgBackupSheetContainer: View {
    @Binding var isPresented: Bool
    @State private var viewModel: PostgresBackupRestoreViewModel
    @Environment(ProjectStore.self) private var projectStore

    init(connection: SavedConnection, session: DatabaseSession, databaseName: String, isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        let authConfig = AppDirector.shared.identityRepository.resolveAuthenticationConfiguration(for: connection, overridePassword: nil)
        let vm = PostgresBackupRestoreViewModel(
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
        PgBackupSidebarSheet(
            viewModel: viewModel,
            customToolPath: projectStore.globalSettings.pgToolCustomPath,
            onDismiss: { isPresented = false }
        )
    }
}

struct PgRestoreSheetContainer: View {
    let connectionSession: ConnectionSession?
    @Binding var isPresented: Bool
    @State private var viewModel: PostgresBackupRestoreViewModel
    @Environment(ProjectStore.self) private var projectStore
    @Environment(EnvironmentState.self) private var environmentState

    private let databaseName: String

    init(connection: SavedConnection, session: DatabaseSession, databaseName: String, connectionSession: ConnectionSession?, isPresented: Binding<Bool>) {
        self.connectionSession = connectionSession
        self._isPresented = isPresented
        self.databaseName = databaseName
        let authConfig = AppDirector.shared.identityRepository.resolveAuthenticationConfiguration(for: connection, overridePassword: nil)
        let vm = PostgresBackupRestoreViewModel(
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
        PgRestoreSidebarSheet(
            viewModel: viewModel,
            customToolPath: projectStore.globalSettings.pgToolCustomPath,
            onDismiss: { isPresented = false }
        )
        .onChange(of: viewModel.restorePhase) { _, newPhase in
            if case .completed = newPhase, let connSession = connectionSession {
                Task {
                    await environmentState.loadSchemaForDatabase(databaseName, connectionSession: connSession)
                }
            }
        }
    }
}
