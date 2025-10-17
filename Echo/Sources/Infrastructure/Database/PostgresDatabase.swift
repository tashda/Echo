import Foundation
import PostgresNIO
import NIOCore
import Logging

typealias PostgresQueryResult = PostgresRowSequence

struct PostgresNIOFactory: DatabaseFactory {
    private let logger = Logger(label: "dk.tippr.echo.postgres")

    func connect(
        host: String,
        port: Int,
        database: String?,
        tls: Bool,
        authentication: DatabaseAuthenticationConfiguration
    ) async throws -> DatabaseSession {
        guard authentication.method == .sqlPassword else {
            throw DatabaseError.authenticationFailed("Windows authentication is not supported for PostgreSQL")
        }
        // PostgreSQL requires a database name, default to "postgres" if none specified
        let effectiveDatabase = (database?.isEmpty == false) ? database : "postgres"
        let databaseLabel = effectiveDatabase ?? "postgres"
        logger.info("Connecting to PostgreSQL at \(host):\(port)/\(databaseLabel)")

        let configuration = PostgresClient.Configuration(
            host: host,
            port: port,
            username: authentication.username,
            password: authentication.password,
            database: effectiveDatabase,
            tls: tls ? .require(.makeClientConfiguration()) : .disable
        )

        let client = PostgresClient(configuration: configuration, backgroundLogger: logger)
        let clientTask = Task {
            await client.run()
        }

        // Ensure the run loop has started before leasing connections to avoid warnings from PostgresNIO
        await Task.yield()

        do {
            _ = try await client.query("SELECT 1", logger: logger)
        } catch {
            clientTask.cancel()
            throw DatabaseError.connectionFailed("Failed to connect: \(error.localizedDescription)")
        }

        return PostgresSession(client: client, clientTask: clientTask, logger: logger)
    }
}

final class PostgresSession: DatabaseSession {
    private let client: PostgresClient
    private let clientTask: Task<Void, Never>
    private let logger: Logger

    init(client: PostgresClient, clientTask: Task<Void, Never>, logger: Logger) {
        self.client = client
        self.clientTask = clientTask
        self.logger = logger
    }

    func close() async {
        clientTask.cancel()
    }

    func simpleQuery(_ sql: String) async throws -> QueryResultSet {
        try await simpleQuery(sql, progressHandler: nil)
    }

    func simpleQuery(_ sql: String, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        if let progressHandler {
            let sanitized = sanitizeSQL(sql)
            return try await streamQuery(sanitizedSQL: sanitized, progressHandler: progressHandler)
        } else {
            return try await executeSimpleQuery(sql)
        }
    }

    private func executeSimpleQuery(_ sql: String) async throws -> QueryResultSet {
        let query = PostgresQuery(unsafeSQL: sql)
        let result = try await client.query(query, logger: logger)

        var columns: [ColumnInfo] = []
        var rows: [[String?]] = []
        rows.reserveCapacity(512)

        let formatterContext = CellFormatterContext()

        for try await row in result {
            if columns.isEmpty {
                for cell in row {
                    columns.append(ColumnInfo(
                        name: cell.columnName,
                        dataType: "\(cell.dataType)",
                        isPrimaryKey: false,
                        isNullable: true,
                        maxLength: nil
                    ))
                }
            }

            var rowValues: [String?] = []
            rowValues.reserveCapacity(row.count)
            for cell in row {
                rowValues.append(formatterContext.stringValue(for: cell))
            }
            rows.append(rowValues)
        }

        let resolvedColumns = columns.isEmpty
            ? [ColumnInfo(name: "result", dataType: "text")]
            : columns

        return QueryResultSet(
            columns: resolvedColumns,
            rows: rows
        )
    }

    private func streamQuery(sanitizedSQL: String, progressHandler: @escaping QueryProgressHandler) async throws -> QueryResultSet {
        let formatterContext = CellFormatterContext()

        let logger = self.logger
        let operationStart = CFAbsoluteTimeGetCurrent()
        var columns: [ColumnInfo] = []
        let streamingPreviewLimit = 512
        let maxFlushLatency: TimeInterval = 0.5
        var previewRows: [[String?]] = []
        previewRows.reserveCapacity(streamingPreviewLimit)
        var totalRowCount = 0
        var worker: ResultStreamBatchWorker?
        var firstBatchLogged = false
        var firstRowLogged = false

        func rawData(for cell: PostgresCell) -> Data? {
            guard var buffer = cell.bytes else { return nil }
            let readable = buffer.readableBytes
            guard readable > 0 else { return Data() }
            if let bytes = buffer.readBytes(length: readable) {
                return Data(bytes)
            }
            return Data()
        }

        func executeVoidStatement(_ sql: String) async throws {
            let statement = PostgresQuery(unsafeSQL: sql)
            let result = try await client.query(statement, logger: logger)
            for try await _ in result {}
        }

        let cursorName = "echo_cursor_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        let previewFetchSize = streamingPreviewLimit
        let backgroundFetchSize = max(4096, streamingPreviewLimit * 4)

        var transactionBegan = false
        var cursorActive = false

        try await executeVoidStatement("BEGIN")
        transactionBegan = true

        do {
            try Task.checkCancellation()

            let declareSQL = "DECLARE \(cursorName) BINARY CURSOR FOR \(sanitizedSQL)"
            try await executeVoidStatement(declareSQL)
            cursorActive = true

            let readyTimestamp = CFAbsoluteTimeGetCurrent()
            let readyMessage = String(
                format: "[PostgresStream] sequence-ready latency=%.3fs",
                readyTimestamp - operationStart
            )
            logger.debug(.init(stringLiteral: readyMessage))
            print(readyMessage)

            var fetchSize = previewFetchSize

            let proxiedHandler: QueryProgressHandler = { update in
                guard !update.appendedRows.isEmpty || !update.encodedRows.isEmpty else {
                    progressHandler(update)
                    return
                }

                if !firstBatchLogged {
                    firstBatchLogged = true
                    let now = CFAbsoluteTimeGetCurrent()
                    let batchSize = max(update.encodedRows.count, update.appendedRows.count)
                    let message = String(
                        format: "[PostgresStream] first-batch rows=%d latency=%.3fs",
                        batchSize,
                        now - operationStart
                    )
                    logger.debug(.init(stringLiteral: message))
                    print(message)
                }

                progressHandler(update)
            }

            fetchLoop: while true {
                try Task.checkCancellation()

                let fetchSQL = "FETCH FORWARD \(fetchSize) FROM \(cursorName)"
                let fetchQuery = PostgresQuery(unsafeSQL: fetchSQL)
                let batchSequence = try await client.query(fetchQuery, logger: logger)

                var batchCount = 0

                for try await row in batchSequence {
                    try Task.checkCancellation()

                    if columns.isEmpty {
                        columns.reserveCapacity(row.count)
                        for cell in row {
                            columns.append(ColumnInfo(
                                name: cell.columnName,
                                dataType: "\(cell.dataType)",
                                isPrimaryKey: false,
                                isNullable: true,
                                maxLength: nil
                            ))
                        }
                        if worker == nil {
                            worker = ResultStreamBatchWorker(
                                label: "dk.tippr.echo.postgres.streamWorker",
                                columns: columns,
                                streamingPreviewLimit: streamingPreviewLimit,
                                maxFlushLatency: maxFlushLatency,
                                operationStart: operationStart,
                                progressHandler: proxiedHandler
                            )
                        }
                    }

                    let currentIndex = totalRowCount
                    let capturePreview = currentIndex < streamingPreviewLimit

                    var rawCells: [Data?] = []
                    rawCells.reserveCapacity(row.count)

                    var previewValues: [String?]? = nil

                    let conversionStart = CFAbsoluteTimeGetCurrent()

                    if capturePreview {
                        var values: [String?] = []
                        values.reserveCapacity(row.count)
                        for cell in row {
                            rawCells.append(rawData(for: cell))
                            values.append(formatterContext.stringValue(for: cell))
                        }
                        previewValues = values
                    } else {
                        for cell in row {
                            rawCells.append(rawData(for: cell))
                        }
                    }

                    let decodeDuration = CFAbsoluteTimeGetCurrent() - conversionStart

                    if let values = previewValues {
                        if previewRows.count < streamingPreviewLimit {
                            previewRows.append(values)
                        }
                    }

                    let encodedRow = ResultBinaryRowCodec.encodeRaw(cells: rawCells)
                    totalRowCount += 1
                    batchCount += 1

                    if !firstRowLogged {
                        firstRowLogged = true
                        let firstRowLatency = CFAbsoluteTimeGetCurrent() - operationStart
                        let message = String(
                            format: "[PostgresStream] first-row latency=%.3fs",
                            firstRowLatency
                        )
                        logger.debug(.init(stringLiteral: message))
                        print(message)
                    }

                    worker?.enqueue(
                        .init(
                            previewValues: previewValues,
                            encodedRow: encodedRow,
                            totalRowCount: totalRowCount,
                            decodeDuration: decodeDuration
                        )
                    )

                    if totalRowCount % 2048 == 0 {
                        await Task.yield()
                    }
                }

                if batchCount == 0 {
                    break fetchLoop
                }

                if batchCount < fetchSize {
                    break fetchLoop
                }

                if fetchSize == previewFetchSize, totalRowCount >= streamingPreviewLimit {
                    fetchSize = backgroundFetchSize
                }

                await Task.yield()
            }

            worker?.finish(totalRowCount: totalRowCount)

            if cursorActive {
                try await executeVoidStatement("CLOSE \(cursorName)")
                cursorActive = false
            }
            if transactionBegan {
                try await executeVoidStatement("COMMIT")
                transactionBegan = false
            }
        } catch {
            worker?.finish(totalRowCount: totalRowCount)

            if cursorActive {
                try? await executeVoidStatement("CLOSE \(cursorName)")
            }
            if transactionBegan {
                try? await executeVoidStatement("ROLLBACK")
            }

            if let cancellation = error as? CancellationError {
                throw cancellation
            }
            throw error
        }

        let totalElapsed = CFAbsoluteTimeGetCurrent() - operationStart
        let completionMessage = String(
            format: "[PostgresStream] completed rows=%d elapsed=%.3fs",
            totalRowCount,
            totalElapsed
        )
        logger.debug(.init(stringLiteral: completionMessage))
        print(completionMessage)

        let resolvedColumns = columns.isEmpty
            ? [ColumnInfo(name: "result", dataType: "text")]
            : columns

        return QueryResultSet(
            columns: resolvedColumns,
            rows: previewRows,
            totalRowCount: totalRowCount
        )
    }

    private func sanitizeSQL(_ sql: String) -> String {
        var trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.last == ";" {
            trimmed.removeLast()
            trimmed = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    func queryWithPaging(_ sql: String, limit: Int, offset: Int) async throws -> QueryResultSet {
        let pagedSQL = "\(sql) LIMIT \(limit) OFFSET \(offset)"
        return try await simpleQuery(pagedSQL)
    }

    func executeUpdate(_ sql: String) async throws -> Int {
        let query = PostgresQuery(unsafeSQL: sql)
        let result = try await client.query(query, logger: logger)

        var count = 0
        for try await _ in result {
            count += 1
        }
        return count
    }

    func listDatabases() async throws -> [String] {
        let sql = """
        SELECT datname
        FROM pg_database
        WHERE datallowconn = true
          AND datistemplate = false
        ORDER BY datname;
        """
        let result = try await performQuery(sql)
        var names: [String] = []
        for try await name in result.decode(String.self) {
            names.append(name)
        }
        return names
    }

    func listSchemas() async throws -> [String] {
        let sql = """
        SELECT schema_name
        FROM information_schema.schemata
        WHERE schema_name NOT IN ('pg_catalog', 'pg_toast', 'information_schema')
          AND schema_name NOT LIKE 'pg_temp_%'
          AND schema_name NOT LIKE 'pg_toast_temp_%'
        ORDER BY schema_name;
        """
        let result = try await performQuery(sql)
        var schemas: [String] = []
        for try await schema in result.decode(String.self) {
            schemas.append(schema)
        }
        return schemas
    }

    func listTablesAndViews(schema: String?) async throws -> [SchemaObjectInfo] {
        let schemaName = schema ?? "public"
        return try await loadSchemaInfo(schemaName, progress: nil).objects
    }

    func getTableSchema(_ tableName: String, schemaName: String?) async throws -> [ColumnInfo] {
        let schema = schemaName ?? "public"
        let columnMap = try await fetchColumnsByObject(schemaName: schema)
        return columnMap[tableName] ?? []
    }

    func getTableStructureDetails(schema: String, table: String) async throws -> TableStructureDetails {
        var columns: [TableStructureDetails.Column] = []

        let columnsSQL = """
        SELECT
            column_name,
            data_type,
            is_nullable,
            column_default,
            generation_expression,
            ordinal_position
        FROM information_schema.columns
        WHERE table_schema = $1 AND table_name = $2
        ORDER BY ordinal_position;
        """

        let columnResult = try await performQuery(columnsSQL, binds: [PostgresData(string: schema), PostgresData(string: table)])
        for try await (name, dataType, nullable, defaultValue, generated, _) in columnResult.decode((String, String, String, String?, String?, Int).self) {
            let column = TableStructureDetails.Column(
                name: name,
                dataType: dataType,
                isNullable: nullable.uppercased() == "YES",
                defaultValue: defaultValue,
                generatedExpression: generated
            )
            columns.append(column)
        }

        // Primary key
        var primaryKeyName: String?
        var primaryKeyColumns: [String] = []
        let primaryKeySQL = """
        SELECT tc.constraint_name, kcu.column_name
        FROM information_schema.table_constraints AS tc
        JOIN information_schema.key_column_usage AS kcu
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
        WHERE tc.constraint_type = 'PRIMARY KEY'
          AND tc.table_schema = $1
          AND tc.table_name = $2
        ORDER BY kcu.ordinal_position;
        """

        let pkResult = try await performQuery(primaryKeySQL, binds: [PostgresData(string: schema), PostgresData(string: table)])
        for try await (name, column) in pkResult.decode((String, String).self) {
            primaryKeyName = name
            primaryKeyColumns.append(column)
        }

        var primaryKey: TableStructureDetails.PrimaryKey?
        if let pkName = primaryKeyName {
            primaryKey = TableStructureDetails.PrimaryKey(name: pkName, columns: primaryKeyColumns)
        }

        // Indexes (non-primary)
        struct IndexAccumulator {
            var isUnique: Bool
            var columns: [TableStructureDetails.Index.Column]
            var filterCondition: String?
        }

        var indexes: [String: IndexAccumulator] = [:]
        let indexSQL = """
        SELECT
            idx.relname AS index_name,
            ix.indisunique,
            ord.position,
            att.attname,
            ((ix.indoption[ord.position] & 1) = 1) AS is_descending,
            pg_get_expr(ix.indpred, tab.oid) AS predicate
        FROM pg_class tab
        JOIN pg_index ix ON tab.oid = ix.indrelid
        JOIN pg_class idx ON idx.oid = ix.indexrelid
        JOIN pg_namespace ns ON ns.oid = tab.relnamespace
        CROSS JOIN LATERAL generate_subscripts(ix.indkey, 1) AS ord(position)
        LEFT JOIN pg_attribute att ON att.attrelid = tab.oid AND att.attnum = ix.indkey[ord.position]
        WHERE ns.nspname = $1
          AND tab.relname = $2
          AND ix.indisprimary = false
        ORDER BY idx.relname, ord.position;
        """

        let indexResult = try await performQuery(indexSQL, binds: [PostgresData(string: schema), PostgresData(string: table)])
        for try await (indexName, isUnique, position, column, isDescending, predicate) in indexResult.decode((String, Bool, Int, String?, Bool, String?).self) {
            var entry = indexes[indexName] ?? IndexAccumulator(isUnique: isUnique, columns: [], filterCondition: predicate)
            entry.filterCondition = predicate
            if let column {
                let sortOrder: TableStructureDetails.Index.Column.SortOrder = isDescending ? .descending : .ascending
                entry.columns.append(
                    TableStructureDetails.Index.Column(
                        name: column,
                        position: position,
                        sortOrder: sortOrder
                    )
                )
            }
            indexes[indexName] = entry
        }

        let indexModels: [TableStructureDetails.Index] = indexes.map { name, value in
            let sortedColumns = value.columns.sorted { $0.position < $1.position }
            return TableStructureDetails.Index(
                name: name,
                columns: sortedColumns,
                isUnique: value.isUnique,
                filterCondition: value.filterCondition?.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        // Unique constraints
        var uniqueConstraints: [String: [String]] = [:]
        let uniqueSQL = """
        SELECT tc.constraint_name, kcu.column_name, kcu.ordinal_position
        FROM information_schema.table_constraints AS tc
        JOIN information_schema.key_column_usage AS kcu
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
        WHERE tc.constraint_type = 'UNIQUE'
          AND tc.table_schema = $1
          AND tc.table_name = $2
        ORDER BY tc.constraint_name, kcu.ordinal_position;
        """

        let uniqueResult = try await performQuery(uniqueSQL, binds: [PostgresData(string: schema), PostgresData(string: table)])
        for try await (name, column, _) in uniqueResult.decode((String, String, Int).self) {
            uniqueConstraints[name, default: []].append(column)
        }

        let uniqueModels: [TableStructureDetails.UniqueConstraint] = uniqueConstraints.map { name, columns in
            TableStructureDetails.UniqueConstraint(name: name, columns: columns)
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        // Foreign keys
        struct ForeignKeyRow {
            let name: String
            let column: String
            let referencedSchema: String
            let referencedTable: String
            let referencedColumn: String
            let onUpdate: String?
            let onDelete: String?
            let position: Int
        }

        var foreignKeyRows: [ForeignKeyRow] = []
        let foreignKeySQL = """
        SELECT
            tc.constraint_name,
            kcu.column_name,
            ccu.table_schema,
            ccu.table_name,
            ccu.column_name,
            rc.update_rule,
            rc.delete_rule,
            kcu.ordinal_position
        FROM information_schema.table_constraints AS tc
        JOIN information_schema.key_column_usage AS kcu
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
        JOIN information_schema.referential_constraints AS rc
          ON rc.constraint_name = tc.constraint_name
          AND rc.constraint_schema = tc.table_schema
        JOIN information_schema.constraint_column_usage AS ccu
          ON ccu.constraint_name = tc.constraint_name
          AND ccu.constraint_schema = tc.constraint_schema
        WHERE tc.constraint_type = 'FOREIGN KEY'
          AND tc.table_schema = $1
          AND tc.table_name = $2
        ORDER BY tc.constraint_name, kcu.ordinal_position;
        """

        let foreignResult = try await performQuery(foreignKeySQL, binds: [PostgresData(string: schema), PostgresData(string: table)])
        for try await (name, column, refSchema, refTable, refColumn, onUpdate, onDelete, position) in foreignResult.decode((String, String, String, String, String, String?, String?, Int).self) {
            foreignKeyRows.append(
                ForeignKeyRow(
                    name: name,
                    column: column,
                    referencedSchema: refSchema,
                    referencedTable: refTable,
                    referencedColumn: refColumn,
                    onUpdate: onUpdate,
                    onDelete: onDelete,
                    position: position
                )
            )
        }

        let groupedFK = Dictionary(grouping: foreignKeyRows, by: { $0.name })
        let foreignKeyModels: [TableStructureDetails.ForeignKey] = groupedFK.map { name, rows in
            let sortedRows = rows.sorted { $0.position < $1.position }
            return TableStructureDetails.ForeignKey(
                name: name,
                columns: sortedRows.map { $0.column },
                referencedSchema: sortedRows.first?.referencedSchema ?? schema,
                referencedTable: sortedRows.first?.referencedTable ?? "",
                referencedColumns: sortedRows.map { $0.referencedColumn },
                onUpdate: sortedRows.first?.onUpdate,
                onDelete: sortedRows.first?.onDelete
            )
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        // Dependencies (incoming foreign keys)
        struct DependencyRow {
            let name: String
            let sourceTable: String
            let referencingColumn: String
            let referencedColumn: String
            let onUpdate: String?
            let onDelete: String?
            let position: Int
        }

        var dependencyRows: [DependencyRow] = []
        let dependencySQL = """
        SELECT
            tc.constraint_name,
            kcu.table_schema,
            kcu.table_name,
            kcu.column_name,
            ccu.column_name,
            rc.update_rule,
            rc.delete_rule,
            kcu.ordinal_position
        FROM information_schema.referential_constraints AS rc
        JOIN information_schema.table_constraints AS tc
          ON tc.constraint_name = rc.constraint_name
          AND tc.constraint_schema = rc.constraint_schema
        JOIN information_schema.key_column_usage AS kcu
          ON kcu.constraint_name = tc.constraint_name
          AND kcu.constraint_schema = tc.constraint_schema
        JOIN information_schema.constraint_column_usage AS ccu
          ON ccu.constraint_name = tc.constraint_name
          AND ccu.constraint_schema = tc.constraint_schema
        WHERE ccu.table_schema = $1
          AND ccu.table_name = $2
        ORDER BY tc.constraint_name, kcu.ordinal_position;
        """

        let dependencyResult = try await performQuery(dependencySQL, binds: [PostgresData(string: schema), PostgresData(string: table)])
        for try await (name, sourceSchema, sourceTable, sourceColumn, targetColumn, onUpdate, onDelete, position) in dependencyResult.decode((String, String, String, String, String, String?, String?, Int).self) {
            let fullSourceTable: String
            if sourceSchema == schema {
                fullSourceTable = sourceTable
            } else {
                fullSourceTable = "\(sourceSchema).\(sourceTable)"
            }

            dependencyRows.append(
                DependencyRow(
                    name: name,
                    sourceTable: fullSourceTable,
                    referencingColumn: sourceColumn,
                    referencedColumn: targetColumn,
                    onUpdate: onUpdate,
                    onDelete: onDelete,
                    position: position
                )
            )
        }

        let groupedDependencies = Dictionary(grouping: dependencyRows, by: { $0.name })
        let dependencyModels: [TableStructureDetails.Dependency] = groupedDependencies.map { name, rows in
            let sortedRows = rows.sorted { $0.position < $1.position }
            return TableStructureDetails.Dependency(
                name: name,
                baseColumns: sortedRows.map { $0.referencingColumn },
                referencedTable: sortedRows.first?.sourceTable ?? "",
                referencedColumns: sortedRows.map { $0.referencedColumn },
                onUpdate: sortedRows.first?.onUpdate,
                onDelete: sortedRows.first?.onDelete
            )
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return TableStructureDetails(
            columns: columns,
            primaryKey: primaryKey,
            indexes: indexModels,
            uniqueConstraints: uniqueModels,
            foreignKeys: foreignKeyModels,
            dependencies: dependencyModels
        )
    }

    private func fetchColumnsByObject(schemaName: String) async throws -> [String: [ColumnInfo]] {
        struct ColumnRecord {
            let name: String
            let dataType: String
            let isNullable: Bool
            let maxLength: Int?
            let ordinal: Int
        }

        var columnsByTable: [String: [ColumnRecord]] = [:]

        let columnsSQL = """
        SELECT table_name, column_name, data_type, is_nullable, character_maximum_length, ordinal_position
        FROM information_schema.columns
        WHERE table_schema = $1
        ORDER BY table_name, ordinal_position;
        """
        let columnResult = try await performQuery(columnsSQL, binds: [PostgresData(string: schemaName)])
        for try await (table, column, dataType, nullable, maxLength, ordinal) in columnResult.decode((String, String, String, String, Int?, Int).self) {
            var list = columnsByTable[table, default: []]
            list.append(
                ColumnRecord(
                    name: column,
                    dataType: dataType,
                    isNullable: nullable.uppercased() == "YES",
                    maxLength: maxLength,
                    ordinal: ordinal
                )
            )
            columnsByTable[table] = list
        }

        let pkSQL = """
        SELECT tc.table_name, kcu.column_name
        FROM information_schema.table_constraints AS tc
        JOIN information_schema.key_column_usage AS kcu
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
        WHERE tc.constraint_type = 'PRIMARY KEY'
          AND tc.table_schema = $1;
        """
        var primaryKeysByTable: [String: Set<String>] = [:]
        let pkResult = try await performQuery(pkSQL, binds: [PostgresData(string: schemaName)])
        for try await (table, column) in pkResult.decode((String, String).self) {
            var columns = primaryKeysByTable[table, default: []]
            columns.insert(column)
            primaryKeysByTable[table] = columns
        }

        let foreignKeysSQL = """
        SELECT
            cls.relname AS table_name,
            att.attname AS column_name,
            nsp_ref.nspname AS referenced_schema,
            cls_ref.relname AS referenced_table,
            att_ref.attname AS referenced_column,
            con.conname AS constraint_name
        FROM pg_constraint con
        JOIN pg_class cls ON cls.oid = con.conrelid
        JOIN pg_namespace nsp ON nsp.oid = cls.relnamespace
        JOIN pg_class cls_ref ON cls_ref.oid = con.confrelid
        JOIN pg_namespace nsp_ref ON nsp_ref.oid = cls_ref.relnamespace
        JOIN LATERAL generate_subscripts(con.conkey, 1) AS idx(pos) ON TRUE
        JOIN pg_attribute att ON att.attrelid = con.conrelid AND att.attnum = con.conkey[idx.pos]
        JOIN pg_attribute att_ref ON att_ref.attrelid = con.confrelid AND att_ref.attnum = con.confkey[idx.pos]
        WHERE con.contype = 'f'
          AND nsp.nspname = $1
        ORDER BY cls.relname, idx.pos;
        """

        var foreignKeysByTable: [String: [String: ColumnInfo.ForeignKeyReference]] = [:]
        let foreignKeysResult = try await performQuery(foreignKeysSQL, binds: [PostgresData(string: schemaName)])
        for try await (table, column, referencedSchema, referencedTable, referencedColumn, constraintName) in foreignKeysResult.decode((String, String, String, String, String, String).self) {
            var tableMap = foreignKeysByTable[table, default: [:]]
            tableMap[column] = ColumnInfo.ForeignKeyReference(
                constraintName: constraintName,
                referencedSchema: referencedSchema,
                referencedTable: referencedTable,
                referencedColumn: referencedColumn
            )
            foreignKeysByTable[table] = tableMap
        }

        // Materialized view columns may not appear in information_schema in some versions
        let matViewColumnSQL = """
        SELECT c.relname, a.attname, pg_catalog.format_type(a.atttypid, a.atttypmod), NOT a.attnotnull, NULL::integer, a.attnum
        FROM pg_attribute a
        JOIN pg_class c ON c.oid = a.attrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = $1
          AND c.relkind = 'm'
          AND a.attnum > 0
          AND NOT a.attisdropped
        ORDER BY c.relname, a.attnum;
        """
        let matResult = try await performQuery(matViewColumnSQL, binds: [PostgresData(string: schemaName)])
        for try await (table, column, dataType, nullable, _, ordinal) in matResult.decode((String, String, String, Bool, Int?, Int).self) {
            var list = columnsByTable[table, default: []]
            list.append(
                ColumnRecord(
                    name: column,
                    dataType: dataType,
                    isNullable: nullable,
                    maxLength: nil,
                    ordinal: ordinal
                )
            )
            columnsByTable[table] = list
        }

        var result: [String: [ColumnInfo]] = [:]
        for (table, records) in columnsByTable {
            let sorted = records.sorted { $0.ordinal < $1.ordinal }
            let primaryKeys = primaryKeysByTable[table] ?? []
            let foreignKeys = foreignKeysByTable[table] ?? [:]
            let columns = sorted.map { record in
                ColumnInfo(
                    name: record.name,
                    dataType: record.dataType,
                    isPrimaryKey: primaryKeys.contains(record.name),
                    isNullable: record.isNullable,
                    maxLength: record.maxLength,
                    foreignKey: foreignKeys[record.name]
                )
            }
            result[table] = columns
        }

        return result
    }

    func getObjectDefinition(objectName: String, schemaName: String, objectType: SchemaObjectInfo.ObjectType) async throws -> String {
        switch objectType {
        case .table, .materializedView:
            let columns = try await getTableSchema(objectName, schemaName: schemaName)
            guard !columns.isEmpty else {
                return "-- No columns available for \(schemaName).\(objectName)"
            }

            let columnLines = columns.map { column -> String in
                var parts = ["\"\(column.name)\" \(column.dataType)"]
                if let maxLength = column.maxLength, maxLength > 0 {
                    parts[0] += "(\(maxLength))"
                }
                if !column.isNullable {
                    parts.append("NOT NULL")
                }
                if column.isPrimaryKey {
                    parts.append("PRIMARY KEY")
                }
                return parts.joined(separator: " ")
            }

            let keyword = objectType == .table ? "TABLE" : "MATERIALIZED VIEW"
            return """
            CREATE \(keyword) "\(schemaName)"."\(objectName)" (
            \(columnLines.joined(separator: ",\n"))
            );
            """

        case .view:
            let sql = """
            SELECT pg_get_viewdef(format('%I.%I', $1, $2)::regclass, true);
            """
            if let definition = try await firstString(sql, binds: [PostgresData(string: schemaName), PostgresData(string: objectName)]) {
                return definition
            }
            return "-- View definition unavailable"

        case .function:
            let sql = """
            SELECT pg_catalog.pg_get_functiondef(p.oid)
            FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = $1 AND p.proname = $2
            ORDER BY p.oid
            LIMIT 1;
            """
            if let definition = try await firstString(sql, binds: [PostgresData(string: schemaName), PostgresData(string: objectName)]) {
                return definition
            }
            return "-- Function definition unavailable"

        case .trigger:
            let sql = """
            SELECT pg_catalog.pg_get_triggerdef(t.oid, true)
            FROM pg_trigger t
            JOIN pg_class c ON c.oid = t.tgrelid
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = $1 AND t.tgname = $2
            ORDER BY t.oid
            LIMIT 1;
            """
            if let definition = try await firstString(sql, binds: [PostgresData(string: schemaName), PostgresData(string: objectName)]) {
                return definition
            }
            return "-- Trigger definition unavailable"
        }
    }

    // MARK: - Helpers

    private func performQuery(_ sql: String, binds: [PostgresData] = []) async throws -> PostgresRowSequence {
        let query = makeQuery(sql, binds: binds)
        return try await client.query(query, logger: logger)
    }

    private func makeQuery(_ sql: String, binds: [PostgresData]) -> PostgresQuery {
        guard !binds.isEmpty else {
            return PostgresQuery(unsafeSQL: sql)
        }

        var bindings = PostgresBindings()
        for bind in binds {
            bindings.append(bind)
        }
        return PostgresQuery(unsafeSQL: sql, binds: bindings)
    }

    private func firstString(_ sql: String, binds: [PostgresData]) async throws -> String? {
        let result = try await performQuery(sql, binds: binds)
        for try await value in result.decode(String?.self) {
            if let value {
                return value
            }
        }
        return nil
    }
}

private struct CellFormatterContext {
    func stringValue(for cell: PostgresCell) -> String? {
        guard let buffer = cell.bytes else { return nil }

        if cell.format == .text {
            let readableBytes = buffer.readableBytes
            guard readableBytes > 0 else { return "" }
            let raw = buffer.getString(at: buffer.readerIndex, length: readableBytes) ?? ""
            if cell.dataType == .bool {
                if raw == "t" { return "true" }
                if raw == "f" { return "false" }
            }
            return raw
        }

        switch cell.dataType {
        case .bool:
            if let value = try? cell.decode(Bool.self) {
                return value ? "true" : "false"
            }
        case .int2:
            return integerString(from: cell, as: Int16.self)
        case .int4:
            return integerString(from: cell, as: Int32.self)
        case .int8:
            return integerString(from: cell, as: Int64.self)
        case .float4:
            if let value = try? cell.decode(Float.self) {
                return String(value)
            }
        case .float8:
            if let value = try? cell.decode(Double.self) {
                return String(value)
            }
        case .numeric, .money:
            if let decimalValue = try? cell.decode(Decimal.self, context: .default) {
                return NSDecimalNumber(decimal: decimalValue).stringValue
            }
        case .json, .jsonb:
            if let string = try? cell.decode(String.self, context: .default) {
                return string
            }
        case .bytea:
            if var mutableBuffer = cell.bytes {
                return hexString(from: &mutableBuffer)
            }
        default:
            if let string = try? cell.decode(String.self, context: .default) {
                return string
            }
        }

        if var mutableBuffer = cell.bytes {
            return hexString(from: &mutableBuffer)
        }
        return nil
    }

    private func integerString<Integer>(from cell: PostgresCell, as type: Integer.Type) -> String?
    where Integer: FixedWidthInteger & PostgresDecodable {
        guard let value = try? cell.decode(type, context: .default) else { return nil }
        return String(value)
    }

    private func hexString(from buffer: inout ByteBuffer) -> String {
        let bytes = buffer.readBytes(length: buffer.readableBytes) ?? []
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}

extension PostgresSession: DatabaseMetadataSession {
    func loadSchemaInfo(
        _ schemaName: String,
        progress: (@Sendable (SchemaObjectInfo.ObjectType, Int, Int) async -> Void)?
    ) async throws -> SchemaInfo {
        let columnsByObject = try await fetchColumnsByObject(schemaName: schemaName)

        var objects: [SchemaObjectInfo] = []

        let tableSQL = """
        SELECT table_name, table_type
        FROM information_schema.tables
        WHERE table_schema = $1
          AND table_type IN ('BASE TABLE', 'VIEW')
        ORDER BY table_type, table_name;
        """
        let tableResult = try await performQuery(tableSQL, binds: [PostgresData(string: schemaName)])
        var tableEntries: [(String, SchemaObjectInfo.ObjectType)] = []
        for try await (name, rawType) in tableResult.decode((String, String).self) {
            let type = SchemaObjectInfo.ObjectType(rawValue: rawType) ?? .table
            tableEntries.append((name, type))
        }

        let materializedViewSQL = """
        SELECT matviewname
        FROM pg_matviews
        WHERE schemaname = $1
        ORDER BY matviewname;
        """
        let matResult = try await performQuery(materializedViewSQL, binds: [PostgresData(string: schemaName)])
        var materializedNames: [String] = []
        for try await name in matResult.decode(String.self) {
            materializedNames.append(name)
        }

        let functionSQL = """
        SELECT routine_name
        FROM information_schema.routines
        WHERE specific_schema = $1
          AND routine_type = 'FUNCTION'
        ORDER BY routine_name;
        """
        let functionResult = try await performQuery(functionSQL, binds: [PostgresData(string: schemaName)])
        var functionNames: [String] = []
        for try await name in functionResult.decode(String.self) {
            functionNames.append(name)
        }

        let triggerSQL = """
        SELECT trigger_name, action_timing, event_manipulation, event_object_table
        FROM information_schema.triggers
        WHERE trigger_schema = $1
        ORDER BY trigger_name;
        """
        let triggerResult = try await performQuery(triggerSQL, binds: [PostgresData(string: schemaName)])
        var triggerRows: [(String, String, String, String)] = []
        for try await tuple in triggerResult.decode((String, String, String, String).self) {
            triggerRows.append(tuple)
        }

        let totalObjectsCount = max(
            tableEntries.count + materializedNames.count + functionNames.count + triggerRows.count,
            1
        )
        var processedObjects = 0

        if let progress {
            await progress(.table, processedObjects, totalObjectsCount)
        }
        for (name, type) in tableEntries {
            processedObjects += 1
            if let progress {
                await progress(type, processedObjects, totalObjectsCount)
            }
            let columns = columnsByObject[name] ?? []
            objects.append(
                SchemaObjectInfo(
                    name: name,
                    schema: schemaName,
                    type: type,
                    columns: columns
                )
            )
        }

        if !materializedNames.isEmpty {
            if let progress {
                await progress(.materializedView, processedObjects, totalObjectsCount)
            }
            for name in materializedNames {
                processedObjects += 1
                if let progress {
                    await progress(.materializedView, processedObjects, totalObjectsCount)
                }
                let columns = columnsByObject[name] ?? []
                objects.append(
                    SchemaObjectInfo(
                        name: name,
                        schema: schemaName,
                        type: .materializedView,
                        columns: columns
                    )
                )
            }
        }

        if !functionNames.isEmpty {
            if let progress {
                await progress(.function, processedObjects, totalObjectsCount)
            }
            for name in functionNames {
                processedObjects += 1
                if let progress {
                    await progress(.function, processedObjects, totalObjectsCount)
                }
                objects.append(
                    SchemaObjectInfo(
                        name: name,
                        schema: schemaName,
                        type: .function
                    )
                )
            }
        }

        if !triggerRows.isEmpty {
            if let progress {
                await progress(.trigger, processedObjects, totalObjectsCount)
            }
            for row in triggerRows {
                let (name, timing, action, table) = row
                let actionDisplay = "\(timing.uppercased()) \(action.uppercased())".trimmingCharacters(in: .whitespaces)
                let tableName = "\(schemaName).\(table)"
                processedObjects += 1
                if let progress {
                    await progress(.trigger, processedObjects, totalObjectsCount)
                }
                objects.append(
                    SchemaObjectInfo(
                        name: name,
                        schema: schemaName,
                        type: .trigger,
                        columns: [],
                        triggerAction: actionDisplay,
                        triggerTable: tableName
                    )
                )
            }
        }

        return SchemaInfo(name: schemaName, objects: objects)
    }
}
