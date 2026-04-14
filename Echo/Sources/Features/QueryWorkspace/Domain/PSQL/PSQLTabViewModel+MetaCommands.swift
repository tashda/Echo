import Foundation

extension PSQLTabViewModel {

    func performMetaCommand(_ command: String) async {
        let parts = command.split(whereSeparator: \.isWhitespace)
        guard let head = parts.first else {
            appendToHistory("ERROR: Empty meta-command.\n")
            return
        }

        switch String(head) {
        case "\\?":
            appendToHistory(supportedCommandsHelp())
        case "\\conninfo":
            appendToHistory(connectionInfo())
        case "\\l":
            await listDatabases()
        case "\\d":
            if parts.count >= 2 {
                await describeObject(named: String(parts[1]))
            } else {
                await listRelations()
            }
        case "\\dt":
            await listTables()
        case "\\dv":
            await listViews()
        case "\\dm":
            await listMaterializedViews()
        case "\\di":
            await listIndexes()
        case "\\df":
            await listFunctions()
        case "\\dn":
            await listSchemas()
        case "\\du":
            await listRoles()
        case "\\x":
            toggleExpandedDisplay()
        case "\\c", "\\connect":
            guard parts.count >= 2 else {
                appendToHistory("ERROR: Usage: \\c <database>\n")
                return
            }
            await reconnect(to: String(parts[1]))
        default:
            appendToHistory(unsupportedCommandMessage(for: String(head)))
        }
    }

    private func listDatabases() async {
        do {
            let databases = try await session.listDatabases()
            appendToHistory(ASCIIPlainTableFormatter.format(
                columns: ["Name"],
                rows: databases.map { [$0] }
            ))
        } catch {
            appendToHistory("ERROR: \(error.localizedDescription)\n")
        }
    }

    private func listSchemas() async {
        do {
            let schemas = try await session.listSchemas()
            appendToHistory(ASCIIPlainTableFormatter.format(
                columns: ["Name"],
                rows: schemas.map { [$0] }
            ))
        } catch {
            appendToHistory("ERROR: \(error.localizedDescription)\n")
        }
    }

    private func listTables() async {
        await listRelations(ofKinds: ["BASE TABLE"])
    }

    private func listRoles() async {
        let sql = """
        SELECT
            rolname AS role_name,
            rolsuper AS superuser,
            rolinherit AS inherit,
            rolcreaterole AS create_role,
            rolcreatedb AS create_db,
            rolcanlogin AS login
        FROM pg_roles
        ORDER BY rolname;
        """

        do {
            let result = try await session.simpleQuery(sql)
            appendToHistory(renderResult(result))
        } catch {
            appendToHistory("ERROR: \(error.localizedDescription)\n")
        }
    }

    private func listRelations() async {
        await listRelations(ofKinds: ["BASE TABLE", "VIEW", "MATERIALIZED VIEW"])
    }

    private func listViews() async {
        await listRelations(ofKinds: ["VIEW"])
    }

    private func listMaterializedViews() async {
        await listRelations(ofKinds: ["MATERIALIZED VIEW"])
    }

    private func listIndexes() async {
        let sql = """
        SELECT
            schemaname AS schema,
            tablename AS table_name,
            indexname AS index_name
        FROM pg_catalog.pg_indexes
        WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
        ORDER BY schemaname, tablename, indexname;
        """

        do {
            let result = try await session.simpleQuery(sql)
            appendToHistory(renderResult(result))
        } catch {
            appendToHistory("ERROR: \(error.localizedDescription)\n")
        }
    }

    private func listFunctions() async {
        let sql = """
        SELECT
            routine_schema,
            routine_name,
            routine_type,
            data_type
        FROM information_schema.routines
        WHERE routine_schema NOT IN ('pg_catalog', 'information_schema')
        ORDER BY routine_schema, routine_name;
        """

        do {
            let result = try await session.simpleQuery(sql)
            appendToHistory(renderResult(result))
        } catch {
            appendToHistory("ERROR: \(error.localizedDescription)\n")
        }
    }

    private func listRelations(ofKinds kinds: [String]) async {
        let quotedKinds = kinds.map { "'\($0.replacingOccurrences(of: "'", with: "''"))'" }.joined(separator: ", ")
        let sql = """
        SELECT
            schemaname AS schema,
            relname AS name,
            CASE relkind
                WHEN 'r' THEN 'table'
                WHEN 'v' THEN 'view'
                WHEN 'm' THEN 'materialized view'
                ELSE relkind::text
            END AS type
        FROM pg_catalog.pg_statio_user_tables
        WHERE \(quotedKinds.contains("'BASE TABLE'") ? "true" : "false")
        UNION ALL
        SELECT
            schemaname AS schema,
            viewname AS name,
            'view' AS type
        FROM pg_catalog.pg_views
        WHERE 'VIEW' IN (\(quotedKinds))
          AND schemaname NOT IN ('pg_catalog', 'information_schema')
        UNION ALL
        SELECT
            schemaname AS schema,
            matviewname AS name,
            'materialized view' AS type
        FROM pg_catalog.pg_matviews
        WHERE 'MATERIALIZED VIEW' IN (\(quotedKinds))
          AND schemaname NOT IN ('pg_catalog', 'information_schema')
        ORDER BY schema, name;
        """

        do {
            let result = try await session.simpleQuery(sql)
            appendToHistory(renderResult(result))
        } catch {
            appendToHistory("ERROR: \(error.localizedDescription)\n")
        }
    }

    private func describeObject(named objectName: String) async {
        let parts = splitQualifiedName(objectName)
        let schemaName = parts.schema ?? "public"
        let object = parts.name

        do {
            let columns = try await session.getTableSchema(object, schemaName: schemaName)
            if !columns.isEmpty {
                let rows = columns.map { column in
                    [
                        column.name,
                        column.dataType,
                        column.isNullable ? "yes" : "no"
                    ]
                }
                appendToHistory("Table \"\(schemaName).\(object)\"\n")
                appendToHistory(ASCIIPlainTableFormatter.format(
                    columns: ["Column", "Type", "Nullable"],
                    rows: rows
                ))
                return
            }
        } catch {
            // Fall through to object-definition lookup.
        }

        let relationLookup = """
        SELECT CASE c.relkind
            WHEN 'v' THEN 'VIEW'
            WHEN 'm' THEN 'MATERIALIZED VIEW'
            ELSE 'BASE TABLE'
        END AS type
        FROM pg_catalog.pg_class c
        JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = '\(escapeSQLLiteral(schemaName))'
          AND c.relname = '\(escapeSQLLiteral(object))'
          AND c.relkind IN ('r', 'v', 'm')
        LIMIT 1;
        """

        do {
            let result = try await session.simpleQuery(relationLookup)
            if let type = result.rows.first?.first ?? nil,
               let objectType = schemaObjectType(forRelationType: type) {
                let definition = try await session.getObjectDefinition(
                    objectName: object,
                    schemaName: schemaName,
                    objectType: objectType
                )
                appendToHistory(definition + "\n")
                return
            }
        } catch {
            appendToHistory("ERROR: \(error.localizedDescription)\n")
            return
        }

        appendToHistory("Did not find relation \"\(objectName)\".\n")
    }

    func reconnect(to databaseName: String) async {
        let trimmed = databaseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            appendToHistory("ERROR: Usage: \\c <database>\n")
            return
        }

        do {
            await session.close()
            let newSession = try await sessionFactory(trimmed)
            self.session = newSession
            activeDatabase = trimmed
            onActiveDatabaseChanged?(trimmed)
            appendToHistory("You are now connected to database \"\(trimmed)\".\n")
            await resolveActiveDatabase()
        } catch {
            appendToHistory("ERROR: \(error.localizedDescription)\n")
        }
    }

    func renderResult(_ result: QueryResultSet) -> String {
        let rowsToRender: [[String?]]
        let wasTruncated = result.rows.count > Self.maxRenderedRows

        if wasTruncated {
            rowsToRender = Array(result.rows.prefix(Self.maxRenderedRows))
        } else {
            rowsToRender = result.rows
        }

        let rendered: String
        if expandedDisplayEnabled {
            rendered = ExpandedPlainFormatter.format(
                columns: result.columns.map(\.name),
                rows: rowsToRender
            )
        } else {
            rendered = ASCIIPlainTableFormatter.format(
                columns: result.columns.map(\.name),
                rows: rowsToRender
            )
        }

        guard wasTruncated else { return rendered }
        return rendered + "Output truncated to \(Self.maxRenderedRows) rows in the managed console. Use a Query tab for large result sets.\n"
    }

    func toggleExpandedDisplay() {
        expandedDisplayEnabled.toggle()
        appendToHistory("Expanded display is \(expandedDisplayEnabled ? "on" : "off").\n")
    }

    func supportedCommandsHelp() -> String {
        """
        Managed Postgres Console commands:
          SQL statements
          \\?           show this help
          \\conninfo    show current connection info
          \\l           list databases
          \\c DB        connect this console tab to database DB
          \\d [NAME]    list relations or describe a relation
          \\dt          list tables
          \\dv          list views
          \\dm          list materialized views
          \\di          list indexes
          \\df          list functions
          \\dn          list schemas
          \\du          list roles
          \\x           toggle expanded output

        Not available in the managed console (use "Open in psql" for these):
          \\!, \\i, \\ir, \\o, \\w, \\copy, \\cd, \\set, \\watch

        """
    }

    func connectionInfo() -> String {
        "You are connected to database \"\(activeDatabase)\" on host \"\(connection.host)\" as user \"\(connection.username)\".\n"
    }

    func unsupportedCommandMessage(for command: String) -> String {
        let nativeOnlyCommands: Set<String> = ["\\!", "\\i", "\\ir", "\\o", "\\w", "\\copy", "\\cd", "\\set", "\\watch", "\\prompt", "\\password"]
        if nativeOnlyCommands.contains(command) {
            return "ERROR: \(command) requires the native psql CLI. Use \"Open in psql\" from the database context menu.\n"
        }
        return "ERROR: Unsupported psql command: \(command)\n"
    }

    func splitQualifiedName(_ name: String) -> (schema: String?, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ".", maxSplits: 1).map(String.init)
        if parts.count == 2 {
            return (unquoteIdentifier(parts[0]), unquoteIdentifier(parts[1]))
        }
        return (nil, unquoteIdentifier(trimmed))
    }

    func unquoteIdentifier(_ identifier: String) -> String {
        guard identifier.hasPrefix("\""), identifier.hasSuffix("\""), identifier.count >= 2 else {
            return identifier
        }
        let inner = String(identifier.dropFirst().dropLast())
        return inner.replacingOccurrences(of: "\"\"", with: "\"")
    }

    func escapeSQLLiteral(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }

    func schemaObjectType(forRelationType relationType: String) -> SchemaObjectInfo.ObjectType? {
        switch relationType.uppercased() {
        case "BASE TABLE":
            return .table
        case "VIEW":
            return .view
        case "MATERIALIZED VIEW":
            return .materializedView
        default:
            return nil
        }
    }

    func appendToHistory(_ text: String) {
        history += text
        trimHistoryIfNeeded()
    }

    func trimHistoryIfNeeded() {
        guard history.count > Self.maxTranscriptCharacters else { return }

        let dropCount = history.count - Self.transcriptTrimTarget
        guard dropCount > 0 else { return }

        let dropIndex = history.index(history.startIndex, offsetBy: dropCount)
        history = "[Earlier console output trimmed to reduce memory use]\n" + String(history[dropIndex...])
    }
}
