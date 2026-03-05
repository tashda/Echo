import XCTest
@testable import Echo

final class MSSQLMetadataLoadingTests: XCTestCase {
    private struct MSSQLConfig {
        let host: String
        let port: Int
        let username: String
        let password: String
        let database: String
        let useTLS: Bool
    }

    private struct TimeoutError: Error {}

    private func withTimeout<T: Sendable>(_ seconds: TimeInterval, operation: @Sendable @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                let nanos = UInt64(max(1, seconds) * 1_000_000_000)
                try await Task.sleep(nanoseconds: nanos)
                throw TimeoutError()
            }

            let result = try await group.next()
            group.cancelAll()
            guard let result else {
                throw TimeoutError()
            }
            return result
        }
    }

    private func loadMSSQLConfig() -> MSSQLConfig? {
        var env = ProcessInfo.processInfo.environment
        if let config = makeConfig(from: env) {
            return config
        }

        if let envFile = defaultEnvFile(),
           let fileVars = parseEnvFile(at: envFile) {
            for (key, value) in fileVars where env[key] == nil {
                env[key] = value
            }
        }

        return makeConfig(from: env)
    }

    private func makeConfig(from env: [String: String]) -> MSSQLConfig? {
        guard
            let host = env["MSSQL_HOST"],
            let portString = env["MSSQL_PORT"], let port = Int(portString),
            let username = env["MSSQL_USERNAME"],
            let password = env["MSSQL_PASSWORD"]
        else {
            return nil
        }

        let database = env["MSSQL_DATABASE"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedDatabase = (database?.isEmpty == false) ? database! : "AdventureWorks2022"
        let useTLS = env["MSSQL_ENABLE_TLS"]?.lowercased() == "true"

        return MSSQLConfig(
            host: host,
            port: port,
            username: username,
            password: password,
            database: resolvedDatabase,
            useTLS: useTLS
        )
    }

    private func parseEnvFile(at path: String) -> [String: String]? {
        guard let contents = try? String(contentsOfFile: path) else {
            return nil
        }
        var result: [String: String] = [:]
        let lines = contents.split(whereSeparator: \.isNewline)
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            var value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
                value = String(value.dropFirst().dropLast())
            }
            result[key] = value
        }
        return result
    }

    private func defaultEnvFile() -> String? {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // MSSQLMetadataLoadingTests.swift
            .deletingLastPathComponent() // EchoTests
        let candidate = root.appendingPathComponent("mssql.env").path
        return FileManager.default.fileExists(atPath: candidate) ? candidate : nil
    }

    private func makeSavedConnection(from config: MSSQLConfig) -> SavedConnection {
        SavedConnection(
            id: UUID(),
            projectID: nil,
            connectionName: "MSSQL Test",
            host: config.host,
            port: config.port,
            database: config.database,
            username: config.username,
            authenticationMethod: .sqlPassword,
            domain: "",
            credentialSource: .manual,
            identityID: nil,
            keychainIdentifier: nil,
            folderID: nil,
            useTLS: config.useTLS,
            databaseType: .microsoftSQL,
            serverVersion: nil,
            colorHex: "#000000",
            logo: nil,
            cachedStructure: nil,
            cachedStructureUpdatedAt: nil
        )
    }

    private func escapeLiteral(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }

    private func escapeIdentifier(_ value: String) -> String {
        value.replacingOccurrences(of: "]", with: "]]")
    }

    private func qualified(_ database: String, object: String) -> String {
        "[\(escapeIdentifier(database))].\(object)"
    }

    private func extractInt(from result: QueryResultSet, named name: String) -> Int? {
        guard let index = result.columns.firstIndex(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else {
            return nil
        }
        guard let row = result.rows.first, index < row.count else {
            return nil
        }
        guard let value = row[index], let intValue = Int(value) else {
            return nil
        }
        return intValue
    }

    private func queryColumnCount(
        session: DatabaseSession,
        database: String,
        schema: String,
        table: String
    ) async throws -> Int {
        let sql = """
        SELECT COUNT(*) AS col_count
        FROM \(qualified(database, object: "sys.columns")) AS c WITH (NOLOCK)
        JOIN \(qualified(database, object: "sys.objects")) AS o WITH (NOLOCK) ON c.object_id = o.object_id
        JOIN \(qualified(database, object: "sys.schemas")) AS s WITH (NOLOCK) ON o.schema_id = s.schema_id
        WHERE s.name = N'\(escapeLiteral(schema))'
          AND o.name = N'\(escapeLiteral(table))';
        """
        let result = try await session.simpleQuery(sql)
        return extractInt(from: result, named: "col_count") ?? 0
    }

    private func queryColumnSample(
        session: DatabaseSession,
        database: String,
        schema: String,
        table: String,
        limit: Int = 16
    ) async throws -> [String] {
        let sql = """
        SELECT TOP (\(limit)) c.name AS column_name
        FROM \(qualified(database, object: "sys.columns")) AS c WITH (NOLOCK)
        JOIN \(qualified(database, object: "sys.objects")) AS o WITH (NOLOCK) ON c.object_id = o.object_id
        JOIN \(qualified(database, object: "sys.schemas")) AS s WITH (NOLOCK) ON o.schema_id = s.schema_id
        WHERE s.name = N'\(escapeLiteral(schema))'
          AND o.name = N'\(escapeLiteral(table))'
        ORDER BY c.column_id;
        """
        let result = try await session.simpleQuery(sql)
        guard let index = result.columns.firstIndex(where: { $0.name.caseInsensitiveCompare("column_name") == .orderedSame }) else {
            return []
        }
        return result.rows.compactMap { row in
            guard index < row.count else {
                return nil
            }
            return row[index]
        }
    }

    @available(macOS 12.0, *)
    func testEchoMSSQLStructureLoadIncludesColumnsAndRoutines() async throws {
        guard let config = loadMSSQLConfig() else {
            throw XCTSkip("MSSQL env not configured; set MSSQL_HOST/MSSQL_PORT/MSSQL_USERNAME/MSSQL_PASSWORD or create mssql.env")
        }

        let session = try await withTimeout(30) {
            try await MSSQLNIOFactory().connect(
                host: config.host,
                port: config.port,
                database: config.database,
                tls: config.useTLS,
                authentication: DatabaseAuthenticationConfiguration(
                    method: .sqlPassword,
                    username: config.username,
                    password: config.password
                )
            )
        }
        defer {
            Task { await session.close() }
        }

        let fetcher = MSSQLStructureFetcher(session: session)
        let saved = makeSavedConnection(from: config)
        let credentials = ConnectionCredentials(
            authentication: DatabaseAuthenticationConfiguration(
                method: .sqlPassword,
                username: config.username,
                password: config.password
            )
        )

        nonisolated(unsafe) let _fetcher = fetcher
        nonisolated(unsafe) let _credentials = credentials
        let structure = try await withTimeout(120) {
            try await _fetcher.fetchStructure(
                for: saved,
                credentials: _credentials,
                selectedDatabase: config.database,
                reuseSession: session,
                databaseFilter: nil,
                cachedStructure: nil,
                progressHandler: { _ in },
                databaseHandler: { _, _, _ in }
            )
        }

        guard let database = structure.databases.first(where: { $0.name.caseInsensitiveCompare(config.database) == .orderedSame }) else {
            XCTFail("Expected structure to include database \(config.database)")
            return
        }

        let productionSchema = database.schemas.first(where: { $0.name.caseInsensitiveCompare("Production") == .orderedSame })
        let productTable = productionSchema?.objects.first(where: { $0.name.caseInsensitiveCompare("Product") == .orderedSame })
        XCTAssertNotNil(productTable, "Expected Production.Product in structure")
        XCTAssertFalse(productTable?.columns.isEmpty ?? true, "Expected Production.Product columns to be loaded")

        let allObjects = database.schemas.flatMap(\.objects)
        XCTAssertTrue(allObjects.contains(where: { $0.type == .procedure }), "Expected at least one stored procedure")
        XCTAssertTrue(allObjects.contains(where: { $0.type == .function }), "Expected at least one function")
        XCTAssertTrue(allObjects.contains(where: { $0.type == .trigger }), "Expected at least one trigger")
    }

    @available(macOS 12.0, *)
    func testEchoMSSQLSessionMetadataQueries() async throws {
        guard let config = loadMSSQLConfig() else {
            throw XCTSkip("MSSQL env not configured; set MSSQL_HOST/MSSQL_PORT/MSSQL_USERNAME/MSSQL_PASSWORD or create mssql.env")
        }

        let session = try await withTimeout(30) {
            try await MSSQLNIOFactory().connect(
                host: config.host,
                port: config.port,
                database: config.database,
                tls: config.useTLS,
                authentication: DatabaseAuthenticationConfiguration(
                    method: .sqlPassword,
                    username: config.username,
                    password: config.password
                )
            )
        }
        defer {
            Task { await session.close() }
        }

        print("[MSSQLMetadataTests] listSchemas starting")
        let schemasStart = Date()
        let schemas = try await withTimeout(30) { try await session.listSchemas() }
        print("[MSSQLMetadataTests] listSchemas completed in \(String(format: "%.3f", Date().timeIntervalSince(schemasStart)))s")
        XCTAssertTrue(schemas.contains(where: { $0.caseInsensitiveCompare("Production") == .orderedSame }))

        print("[MSSQLMetadataTests] listTablesAndViews starting")
        let objectsStart = Date()
        let objects = try await withTimeout(30) { try await session.listTablesAndViews(schema: "Production") }
        print("[MSSQLMetadataTests] listTablesAndViews completed in \(String(format: "%.3f", Date().timeIntervalSince(objectsStart)))s")
        XCTAssertTrue(objects.contains(where: { $0.name.caseInsensitiveCompare("Product") == .orderedSame }))

        print("[MSSQLMetadataTests] getTableSchema starting")
        let columnsStart = Date()
        let columns = try await withTimeout(30) {
            try await session.getTableSchema("Product", schemaName: "Production")
        }
        print("[MSSQLMetadataTests] getTableSchema completed in \(String(format: "%.3f", Date().timeIntervalSince(columnsStart)))s")
        XCTAssertFalse(columns.isEmpty, "Expected Production.Product columns")
    }

    @available(macOS 12.0, *)
    func testEchoMSSQLMetadataDebugFullLoad() async throws {
        guard let config = loadMSSQLConfig() else {
            throw XCTSkip("MSSQL env not configured; set MSSQL_HOST/MSSQL_PORT/MSSQL_USERNAME/MSSQL_PASSWORD or create mssql.env")
        }

        let session = try await withTimeout(30) {
            try await MSSQLNIOFactory().connect(
                host: config.host,
                port: config.port,
                database: config.database,
                tls: config.useTLS,
                authentication: DatabaseAuthenticationConfiguration(
                    method: .sqlPassword,
                    username: config.username,
                    password: config.password
                )
            )
        }
        defer {
            Task { await session.close() }
        }

        let fetcher = MSSQLStructureFetcher(session: session)
        let saved = makeSavedConnection(from: config)
        let credentials = ConnectionCredentials(
            authentication: DatabaseAuthenticationConfiguration(
                method: .sqlPassword,
                username: config.username,
                password: config.password
            )
        )

        nonisolated(unsafe) let _fetcher2 = fetcher
        nonisolated(unsafe) let _credentials2 = credentials
        let structure = try await withTimeout(180) {
            try await _fetcher2.fetchStructure(
                for: saved,
                credentials: _credentials2,
                selectedDatabase: config.database,
                reuseSession: session,
                databaseFilter: nil,
                cachedStructure: nil,
                progressHandler: { progress in
                    if let message = progress.message {
                        print("[MSSQLMetadataDebug] progress=\(progress.fraction) \(message)")
                    }
                },
                databaseHandler: { database, _, _ in
                    print("[MSSQLMetadataDebug] loaded database=\(database.name) schemas=\(database.schemas.count)")
                }
            )
        }

        guard let database = structure.databases.first(where: { $0.name.caseInsensitiveCompare(config.database) == .orderedSame }) else {
            XCTFail("Expected structure to include database \(config.database)")
            return
        }

        let tableObjects = database.schemas
            .flatMap(\.objects)
            .filter { $0.type == .table || $0.type == .view || $0.type == .materializedView }
        let viewObjects = tableObjects.filter { $0.type == .view || $0.type == .materializedView }
        let baseTableObjects = tableObjects.filter { $0.type == .table }

        print("[MSSQLMetadataDebug] objects total=\(tableObjects.count) tables=\(baseTableObjects.count) views=\(viewObjects.count)")

        var missingColumns: [String] = []

        for object in tableObjects where object.columns.isEmpty {
            let fullName = "\(object.schema).\(object.name)"
            var sysCount: Int? = nil
            var sysSample: [String] = []
            var directCount: Int? = nil

            nonisolated(unsafe) let _self = self
            nonisolated(unsafe) let _session = session
            do {
                sysCount = try await withTimeout(15) {
                    try await _self.queryColumnCount(
                        session: _session,
                        database: config.database,
                        schema: object.schema,
                        table: object.name
                    )
                }
            } catch {
                print("[MSSQLMetadataDebug] sys.columns count failed for \(fullName): \(error)")
            }

            do {
                sysSample = try await withTimeout(15) {
                    try await _self.queryColumnSample(
                        session: _session,
                        database: config.database,
                        schema: object.schema,
                        table: object.name
                    )
                }
            } catch {
                print("[MSSQLMetadataDebug] sys.columns sample failed for \(fullName): \(error)")
            }

            do {
                let direct = try await withTimeout(15) {
                    try await session.getTableSchema(object.name, schemaName: object.schema)
                }
                directCount = direct.count
            } catch {
                print("[MSSQLMetadataDebug] getTableSchema failed for \(fullName): \(error)")
            }

            print("[MSSQLMetadataDebug] missing columns for \(fullName) type=\(object.type) sys.columns=\(sysCount.map(String.init) ?? "nil") getTableSchema=\(directCount.map(String.init) ?? "nil") sample=[\(sysSample.joined(separator: ", "))]")
            missingColumns.append(fullName)
        }

        let shift = database.schemas
            .first(where: { $0.name.caseInsensitiveCompare("HumanResources") == .orderedSame })?
            .objects
            .first(where: { $0.name.caseInsensitiveCompare("Shift") == .orderedSame })
        XCTAssertNotNil(shift, "Expected HumanResources.Shift to exist")
        XCTAssertFalse(shift?.columns.isEmpty ?? true, "Expected HumanResources.Shift columns to be loaded")

        let vEmployee = database.schemas
            .first(where: { $0.name.caseInsensitiveCompare("HumanResources") == .orderedSame })?
            .objects
            .first(where: { $0.name.caseInsensitiveCompare("vEmployee") == .orderedSame })
        XCTAssertNotNil(vEmployee, "Expected HumanResources.vEmployee view to exist")
        XCTAssertEqual(vEmployee?.type, .view, "Expected HumanResources.vEmployee to be classified as a view")
        XCTAssertFalse(viewObjects.isEmpty, "Expected at least one view to be classified as view")

        XCTAssertTrue(missingColumns.isEmpty, "Missing columns for: \(missingColumns.joined(separator: ", "))")
    }
}
