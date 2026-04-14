import Foundation
import AppKit
import Logging
import UniformTypeIdentifiers

// MARK: - Database Loading, Object Selection, and Output Delivery

extension DataMigrationWizardViewModel {

    // MARK: - Database Loading

    func loadSourceDatabases() {
        guard let session = sourceSession else { return }
        isLoadingSourceDatabases = true
        Task {
            do {
                let databases = try await session.session.listDatabases()
                self.sourceDatabases = databases
                if self.sourceDatabaseName.isEmpty, let first = databases.first {
                    self.sourceDatabaseName = first
                }
            } catch {
                logger.error("Failed to load source databases: \(error)")
            }
            self.isLoadingSourceDatabases = false
        }
    }

    func loadTargetDatabases() {
        guard let session = targetSession else { return }
        isLoadingTargetDatabases = true
        Task {
            do {
                let databases = try await session.session.listDatabases()
                self.targetDatabases = databases
                if self.targetDatabaseName.isEmpty, let first = databases.first {
                    self.targetDatabaseName = first
                }
            } catch {
                logger.error("Failed to load target databases: \(error)")
            }
            self.isLoadingTargetDatabases = false
        }
    }

    // MARK: - Object Loading

    func loadSourceObjects() {
        guard let session = sourceSession else { return }
        isLoadingObjects = true
        Task {
            do {
                let dbSession = try await session.session.sessionForDatabase(sourceDatabaseName)
                let schemas = try await dbSession.listSchemas()
                var allObjects: [MigrationObject] = []
                for schema in schemas {
                    let tables = try await dbSession.listTablesAndViews(schema: schema)
                    for obj in tables where obj.type == .table {
                        allObjects.append(MigrationObject(
                            id: "\(obj.schema).\(obj.name)",
                            schema: obj.schema,
                            name: obj.name,
                            objectType: "Table"
                        ))
                    }
                }
                self.sourceObjects = allObjects
                self.selectedObjectIDs = Set(allObjects.map(\.id))
            } catch {
                logger.error("Failed to load source objects: \(error)")
            }
            self.isLoadingObjects = false
        }
    }

    // MARK: - Object Selection

    func selectAll() {
        selectedObjectIDs = Set(sourceObjects.map(\.id))
    }

    func deselectAll() {
        selectedObjectIDs.removeAll()
    }

    func toggleObject(_ obj: MigrationObject) {
        if selectedObjectIDs.contains(obj.id) {
            selectedObjectIDs.remove(obj.id)
        } else {
            selectedObjectIDs.insert(obj.id)
        }
    }

    // MARK: - Output Delivery

    func deliverOutput() {
        switch outputDestination {
        case .execute:
            executeMigration()
        case .queryTab:
            onOpenInQueryTab?(generatedSQL)
        case .clipboard:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(generatedSQL, forType: .string)
        case .file:
            saveToFile()
        }
    }

    func saveToFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "sql")!]
        panel.nameFieldStringValue = "migration_\(sourceDatabaseName)_to_\(targetDatabaseName).sql"
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try generatedSQL.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                logger.error("Failed to save migration script: \(error)")
            }
        }
    }
}
