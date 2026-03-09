import Foundation
@testable import Echo

enum TestFixtures {
    // MARK: - SavedConnection

    static func savedConnection(
        id: UUID = UUID(),
        projectID: UUID? = nil,
        connectionName: String = "Test Connection",
        host: String = "localhost",
        port: Int = 5432,
        database: String = "testdb",
        username: String = "testuser",
        authenticationMethod: DatabaseAuthenticationMethod = .sqlPassword,
        domain: String = "",
        credentialSource: CredentialSource = .manual,
        identityID: UUID? = nil,
        keychainIdentifier: String? = nil,
        folderID: UUID? = nil,
        useTLS: Bool = false,
        databaseType: DatabaseType = .postgresql,
        serverVersion: String? = nil,
        colorHex: String = "007AFF",
        cachedStructure: DatabaseStructure? = nil
    ) -> SavedConnection {
        SavedConnection(
            id: id,
            projectID: projectID,
            connectionName: connectionName,
            host: host,
            port: port,
            database: database,
            username: username,
            authenticationMethod: authenticationMethod,
            domain: domain,
            credentialSource: credentialSource,
            identityID: identityID,
            keychainIdentifier: keychainIdentifier,
            folderID: folderID,
            useTLS: useTLS,
            databaseType: databaseType,
            serverVersion: serverVersion,
            colorHex: colorHex,
            cachedStructure: cachedStructure
        )
    }

    // MARK: - Project

    static func project(
        id: UUID = UUID(),
        name: String = "Test Project",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        colorHex: String = "007AFF",
        iconName: String? = nil,
        isDefault: Bool = false,
        settings: ProjectSettings = ProjectSettings(),
        bookmarks: [Bookmark] = []
    ) -> Project {
        Project(
            id: id,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            colorHex: colorHex,
            iconName: iconName,
            isDefault: isDefault,
            settings: settings,
            bookmarks: bookmarks
        )
    }

    // MARK: - GlobalSettings

    static func globalSettings() -> GlobalSettings {
        GlobalSettings()
    }

    // MARK: - DatabaseStructure

    static func databaseStructure(
        serverVersion: String? = "15.0",
        databaseCount: Int = 1,
        schemasPerDatabase: Int = 1,
        tablesPerSchema: Int = 2
    ) -> DatabaseStructure {
        var databases: [DatabaseInfo] = []
        for dbIndex in 0..<databaseCount {
            var schemas: [SchemaInfo] = []
            for schemaIndex in 0..<schemasPerDatabase {
                var objects: [SchemaObjectInfo] = []
                for tableIndex in 0..<tablesPerSchema {
                    objects.append(schemaObjectInfo(
                        name: "table_\(tableIndex)",
                        schema: "schema_\(schemaIndex)",
                        type: .table
                    ))
                }
                schemas.append(SchemaInfo(name: "schema_\(schemaIndex)", objects: objects))
            }
            databases.append(DatabaseInfo(name: "db_\(dbIndex)", schemas: schemas))
        }
        return DatabaseStructure(serverVersion: serverVersion, databases: databases)
    }

    // MARK: - TableStructureDetails

    static func tableStructureDetails(
        columnCount: Int = 3,
        primaryKeyName: String? = "pk_id",
        foreignKeys: [TableStructureDetails.ForeignKey] = []
    ) -> TableStructureDetails {
        var columns: [TableStructureDetails.Column] = []
        for i in 0..<columnCount {
            columns.append(TableStructureDetails.Column(
                name: "col_\(i)",
                dataType: i == 0 ? "integer" : "text",
                isNullable: i != 0,
                defaultValue: nil,
                generatedExpression: nil
            ))
        }
        let pk: TableStructureDetails.PrimaryKey? = primaryKeyName.map {
            TableStructureDetails.PrimaryKey(name: $0, columns: ["col_0"])
        }
        return TableStructureDetails(
            columns: columns,
            primaryKey: pk,
            indexes: [],
            uniqueConstraints: [],
            foreignKeys: foreignKeys,
            dependencies: []
        )
    }

    // MARK: - ColumnInfo

    static func columnInfo(
        name: String = "id",
        dataType: String = "integer",
        isPrimaryKey: Bool = false,
        isNullable: Bool = true,
        maxLength: Int? = nil,
        comment: String? = nil
    ) -> ColumnInfo {
        ColumnInfo(
            name: name,
            dataType: dataType,
            isPrimaryKey: isPrimaryKey,
            isNullable: isNullable,
            maxLength: maxLength,
            comment: comment
        )
    }

    // MARK: - SchemaObjectInfo

    static func schemaObjectInfo(
        name: String = "test_table",
        schema: String = "public",
        type: SchemaObjectInfo.ObjectType = .table,
        columns: [ColumnInfo] = [],
        triggerAction: String? = nil,
        triggerTable: String? = nil
    ) -> SchemaObjectInfo {
        SchemaObjectInfo(
            name: name,
            schema: schema,
            type: type,
            columns: columns,
            triggerAction: triggerAction,
            triggerTable: triggerTable
        )
    }

    // MARK: - QueryResultSet

    static func queryResultSet(
        columns: [String] = ["id", "name"],
        rows: [[String?]] = [["1", "Alice"], ["2", "Bob"]]
    ) -> QueryResultSet {
        QueryResultSet(columns: columns, rows: rows)
    }

    // MARK: - Bookmark

    static func bookmark(
        id: UUID = UUID(),
        connectionID: UUID = UUID(),
        databaseName: String? = "testdb",
        title: String? = nil,
        query: String = "SELECT * FROM users",
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        source: Bookmark.Source = .queryEditorSelection
    ) -> Bookmark {
        Bookmark(
            id: id,
            connectionID: connectionID,
            databaseName: databaseName,
            title: title,
            query: query,
            createdAt: createdAt,
            updatedAt: updatedAt,
            source: source
        )
    }

    // MARK: - SavedIdentity

    static func savedIdentity(
        id: UUID = UUID(),
        projectID: UUID? = nil,
        name: String = "Test Identity",
        username: String = "testuser",
        keychainIdentifier: String? = nil
    ) -> SavedIdentity {
        SavedIdentity(
            id: id,
            projectID: projectID,
            name: name,
            username: username,
            keychainIdentifier: keychainIdentifier
        )
    }

    // MARK: - SavedFolder

    static func savedFolder(
        name: String = "Test Folder",
        projectID: UUID? = nil,
        colorHex: String = "007AFF"
    ) -> SavedFolder {
        SavedFolder(name: name, projectID: projectID, colorHex: colorHex)
    }

    // MARK: - ClipboardHistoryEntry

    static func clipboardHistoryEntry(
        id: UUID = UUID(),
        source: ClipboardHistoryEntry.Source = .queryEditor,
        content: String = "SELECT * FROM users",
        timestamp: Date = Date(),
        metadata: ClipboardHistoryEntry.Metadata = .empty
    ) -> ClipboardHistoryEntry {
        ClipboardHistoryEntry(
            id: id,
            source: source,
            content: content,
            timestamp: timestamp,
            metadata: metadata
        )
    }
}
