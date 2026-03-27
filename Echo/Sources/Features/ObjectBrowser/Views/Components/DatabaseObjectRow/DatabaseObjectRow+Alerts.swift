import SwiftUI

/// Conditionally applies alert/sheet modifiers only when one is active.
/// This avoids SwiftUI's AlertStorage copy/destroy overhead on every render
/// for the 217+ rows that never have an active alert.
struct DatabaseObjectRowAlerts: ViewModifier {
    let object: SchemaObjectInfo
    let connection: SavedConnection
    let databaseName: String?

    @Binding var showDropAlert: Bool
    @Binding var showTruncateAlert: Bool
    @Binding var showRenameAlert: Bool
    @Binding var renameText: String
    @Binding var pendingDropIncludeIfExists: Bool
    @Binding var showBulkImportSheet: Bool
    @Binding var showExportSheet: Bool
    @Binding var showGenerateScriptsWizard: Bool

    let performDrop: (Bool) -> Void
    let performTruncate: () -> Void
    let performRename: () -> Void

    @Environment(EnvironmentState.self) private var environmentState

    private var hasActivePresentation: Bool {
        showDropAlert || showTruncateAlert || showRenameAlert
            || showBulkImportSheet || showExportSheet || showGenerateScriptsWizard
    }

    private func objectTypeDisplayName() -> String {
        switch object.type {
        case .table: "Table"
        case .view: "View"
        case .materializedView: "Materialized View"
        case .function: "Function"
        case .procedure: "Procedure"
        case .trigger: "Trigger"
        case .extension: "Extension"
        case .sequence: "Sequence"
        case .type: "Type"
        case .synonym: "Synonym"
        }
    }

    func body(content: Content) -> some View {
        if hasActivePresentation {
            content
                .alert("Drop \(objectTypeDisplayName())?", isPresented: $showDropAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Drop", role: .destructive) { performDrop(pendingDropIncludeIfExists) }
                } message: {
                    Text("Are you sure you want to drop the \(objectTypeDisplayName().lowercased()) \(object.fullName)? This action cannot be undone.")
                }
                .alert("Truncate \(objectTypeDisplayName())?", isPresented: $showTruncateAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Truncate", role: .destructive) { performTruncate() }
                } message: {
                    Text("Are you sure you want to truncate the \(objectTypeDisplayName().lowercased()) \(object.fullName)? This action cannot be undone.")
                }
                .alert("Rename \(objectTypeDisplayName())", isPresented: $showRenameAlert) {
                    TextField("Name", text: $renameText)
                    Button("Cancel", role: .cancel) {}
                    Button("Rename") { performRename() }
                } message: {
                    Text("Enter a new name for the \(objectTypeDisplayName().lowercased()) \(object.fullName).")
                }
                .sheet(isPresented: $showBulkImportSheet) {
                    if let session = environmentState.sessionGroup.sessionForConnection(connection.id) {
                        BulkImportSheet(
                            viewModel: {
                                let defaultSchema: String
                                switch connection.databaseType {
                                case .microsoftSQL: defaultSchema = object.schema.isEmpty ? "dbo" : object.schema
                                case .postgresql: defaultSchema = object.schema.isEmpty ? "public" : object.schema
                                case .sqlite, .mysql: defaultSchema = object.schema
                                }
                                let vm = BulkImportViewModel(
                                    session: session.session,
                                    connectionSession: session,
                                    databaseType: connection.databaseType,
                                    schema: defaultSchema,
                                    tableName: object.name
                                )
                                vm.activityEngine = AppDirector.shared.activityEngine
                                return vm
                            }(),
                            onDismiss: { showBulkImportSheet = false }
                        )
                    }
                }
                .sheet(isPresented: $showGenerateScriptsWizard) {
                    if let session = environmentState.sessionGroup.sessionForConnection(connection.id),
                       let dbName = databaseName {
                        let vm = GenerateScriptsWizardViewModel(
                            session: session.session,
                            databaseName: dbName
                        )
                        GenerateScriptsWizardView(viewModel: vm)
                            .onAppear {
                                vm.onOpenInQueryTab = { script in
                                    environmentState.openQueryTab(for: session, presetQuery: script, database: dbName)
                                }
                            }
                    }
                }
                .sheet(isPresented: $showExportSheet) {
                    if let session = environmentState.sessionGroup.sessionForConnection(connection.id) {
                        let vm = DataExportViewModel(
                            session: session.session,
                            databaseType: connection.databaseType,
                            schema: object.schema,
                            tableName: object.name
                        )
                        DataExportSheet(viewModel: vm, onDismiss: { showExportSheet = false })
                    }
                }
        } else {
            content
        }
    }
}
