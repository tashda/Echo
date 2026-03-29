import SwiftUI

extension SchemaDiagramView {

    // MARK: - Create Table

    func createTableFromDiagram() {
        guard let context = viewModel.context,
              let session = environmentState.sessionGroup.activeSessions.first(where: { $0.id == context.connectionSessionID }) else {
            return
        }

        let schemaName = context.object.schema
        let databaseType = session.connection.databaseType
        let sql = createTableTemplate(databaseType: databaseType, schemaName: schemaName)
        let database = databaseForContext(session: session, context: context)
        environmentState.openQueryTab(for: session, presetQuery: sql, database: database)
    }

    // MARK: - Create Relationship

    func createRelationshipFromDiagram() {
        guard let context = viewModel.context,
              let session = environmentState.sessionGroup.activeSessions.first(where: { $0.id == context.connectionSessionID }) else {
            return
        }

        let databaseType = session.connection.databaseType
        let schemaName = context.object.schema
        let sql = createRelationshipTemplate(databaseType: databaseType, schemaName: schemaName)
        let database = databaseForContext(session: session, context: context)
        environmentState.openQueryTab(for: session, presetQuery: sql, database: database)
    }

    // MARK: - Model Synchronization

    func synchronizeModelWithDatabase() {
        guard let context = viewModel.context,
              let session = environmentState.sessionGroup.activeSessions.first(where: { $0.id == context.connectionSessionID }) else {
            return
        }

        // Open schema diff pre-configured to compare the diagram's schema
        let tab = session.addSchemaDiffTab()
        if let schemaDiff = tab.schemaDiffVM {
            let resolved = SchemaDiffViewModel.resolvedSchemas(
                availableSchemas: schemaDiff.availableSchemas,
                preferredSource: context.object.schema,
                currentSource: context.object.schema,
                currentTarget: schemaDiff.targetSchema
            )
            schemaDiff.sourceSchema = resolved.source
            schemaDiff.targetSchema = resolved.target
            // Auto-run the comparison so users see changes immediately
            Task {
                await schemaDiff.compare()
            }
        }
    }

    // MARK: - Annotations

    func addAnnotationToDiagram() {
        let centerX = -contentOffset.width / zoom + viewSize.width / (2 * zoom)
        let centerY = -contentOffset.height / zoom + viewSize.height / (2 * zoom)
        viewModel.addAnnotation(at: CGPoint(x: centerX, y: centerY))
    }

    // MARK: - Helpers

    private func databaseForContext(session: ConnectionSession, context: SchemaDiagramContext) -> String? {
        if session.connection.databaseType == .mysql {
            return context.object.schema
        }
        return session.connection.database.isEmpty ? nil : session.connection.database
    }

    private func createTableTemplate(databaseType: DatabaseType, schemaName: String) -> String {
        switch databaseType {
        case .microsoftSQL:
            return """
            CREATE TABLE [\(schemaName)].[NewTable] (
                [Id] INT IDENTITY(1,1) PRIMARY KEY,
                [Name] NVARCHAR(100) NOT NULL
            );
            GO
            """
        case .postgresql:
            return """
            CREATE TABLE \(schemaName).new_table (
                id SERIAL PRIMARY KEY,
                name TEXT NOT NULL
            );
            """
        case .mysql:
            return """
            CREATE TABLE new_table (
                id INT AUTO_INCREMENT PRIMARY KEY,
                name VARCHAR(100) NOT NULL
            );
            """
        case .sqlite:
            return """
            CREATE TABLE new_table (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL
            );
            """
        }
    }

    private func createRelationshipTemplate(databaseType: DatabaseType, schemaName: String) -> String {
        let tableNames = viewModel.nodes.prefix(2).map(\.name)
        let sourceTable = tableNames.first ?? "source_table"
        let targetTable = tableNames.count > 1 ? tableNames[1] : "target_table"

        switch databaseType {
        case .microsoftSQL:
            return """
            ALTER TABLE [\(schemaName)].[\(sourceTable)]
            ADD CONSTRAINT [FK_\(sourceTable)_\(targetTable)]
                FOREIGN KEY ([ColumnName])
                REFERENCES [\(schemaName)].[\(targetTable)] ([Id]);
            GO
            """
        case .postgresql:
            return """
            ALTER TABLE \(schemaName).\(sourceTable)
            ADD CONSTRAINT fk_\(sourceTable)_\(targetTable)
                FOREIGN KEY (column_name)
                REFERENCES \(schemaName).\(targetTable) (id);
            """
        case .mysql:
            return """
            ALTER TABLE `\(sourceTable)`
            ADD CONSTRAINT `fk_\(sourceTable)_\(targetTable)`
                FOREIGN KEY (`column_name`)
                REFERENCES `\(targetTable)` (`id`);
            """
        case .sqlite:
            return """
            -- SQLite requires recreating the table to add foreign keys.
            -- Use the table editor instead for SQLite FK management.
            """
        }
    }
}
