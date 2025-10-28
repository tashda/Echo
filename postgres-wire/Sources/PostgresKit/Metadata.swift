import Foundation
import Logging
import PostgresWire

public enum SchemaObjectKind: String, Sendable {
    case table, view, materializedView
}

public struct SchemaObject: Sendable {
    public var schema: String
    public var name: String
    public var kind: SchemaObjectKind
}

public struct PostgresMetadata: Sendable {
    public init() {}
    private func quoteLiteral(_ s: String) -> String { s.replacingOccurrences(of: "'", with: "''") }

    public func listDatabases(using client: PostgresDatabaseClient) async throws -> [String] {
        var names: [String] = []
        let rows = try await client.simpleQuery("SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname")
        for try await name in rows.decode(String.self) { names.append(name) }
        return names
    }

    public func listSchemas(using client: PostgresDatabaseClient) async throws -> [String] {
        let sql = """
        SELECT schema_name
        FROM information_schema.schemata
        WHERE schema_name NOT IN ('pg_catalog','pg_toast','information_schema')
          AND schema_name NOT LIKE 'pg_temp_%'
          AND schema_name NOT LIKE 'pg_toast_temp_%'
        ORDER BY schema_name
        """
        var names: [String] = []
        let rows = try await client.simpleQuery(sql)
        for try await name in rows.decode(String.self) { names.append(name) }
        return names
    }

    public func listTablesAndViews(using client: PostgresDatabaseClient, schema: String) async throws -> [SchemaObject] {
        let sql = """
        SELECT table_schema, table_name, table_type
        FROM information_schema.tables
        WHERE table_schema = $1
        ORDER BY table_name
        """
        let rows = try await client.withConnection { conn in
            try await conn.queryPreparedRows(sql, binds: [PGData(string: schema)])
        }
        var objects: [SchemaObject] = []
        for row in rows {
            let (schema, name, type) = try row.decode((String, String, String).self)
            let kind: SchemaObjectKind
            switch type.uppercased() {
            case "BASE TABLE": kind = .table
            case "VIEW": kind = .view
            default: kind = .table
            }
            objects.append(.init(schema: schema, name: name, kind: kind))
        }
        return objects
    }

    public struct Column: Sendable {
        public let name: String
        public let dataType: String
        public let isNullable: Bool
        public let defaultValue: String?
    }

    public struct ColumnDetail: Sendable {
        public struct ForeignKeyRef: Sendable {
            public let constraintName: String
            public let referencedSchema: String
            public let referencedTable: String
            public let referencedColumn: String
        }
        public let name: String
        public let dataType: String
        public let isNullable: Bool
        public let maxLength: Int?
        public let isPrimaryKey: Bool
        public let foreignKey: ForeignKeyRef?
    }

    public func listColumns(using client: PostgresDatabaseClient, schema: String, table: String) async throws -> [Column] {
        let sql = """
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = $1 AND table_name = $2
        ORDER BY ordinal_position
        """
        let rows = try await client.withConnection { conn in
            try await conn.queryPreparedRows(sql, binds: [PGData(string: schema), PGData(string: table)])
        }
        var out: [Column] = []
        for row in rows {
            let (name, dataType, nullable, defaultValue) = try row.decode((String, String, String, String?).self)
            out.append(Column(name: name, dataType: dataType, isNullable: nullable.uppercased() == "YES", defaultValue: defaultValue))
        }
        return out
    }

    public struct Index: Sendable {
        public struct Column: Sendable {
            public let name: String
            public let isDescending: Bool
        }
        public let name: String
        public let isUnique: Bool
        public let columns: [Column]
        public let predicate: String?
    }

    public func listIndexes(using client: PostgresDatabaseClient, schema: String, table: String) async throws -> [Index] {
        let sql = """
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
        ORDER BY idx.relname, ord.position
        """
        let rows = try await client.withConnection { conn in
            try await conn.queryPreparedRows(sql, binds: [PGData(string: schema), PGData(string: table)])
        }
        var acc: [String: (unique: Bool, cols: [Index.Column], predicate: String?)] = [:]
        for row in rows {
            let (indexName, isUnique, _position, attname, isDesc, predicate) = try row.decode((String, Bool, Int, String?, Bool?, String?).self)
            var entry = acc[indexName] ?? (isUnique, [], nil)
            if let attname {
                entry.cols.append(Index.Column(name: attname, isDescending: isDesc ?? false))
            }
            entry.unique = isUnique
            entry.predicate = predicate
            acc[indexName] = entry
        }
        return acc.sorted { $0.key < $1.key }.map { name, e in Index(name: name, isUnique: e.unique, columns: e.cols, predicate: e.predicate) }
    }

    public struct PrimaryKey: Sendable {
        public let name: String
        public let columns: [String]
    }

    public func primaryKey(using client: PostgresDatabaseClient, schema: String, table: String) async throws -> PrimaryKey? {
        let sql = """
        SELECT tc.constraint_name, kcu.column_name
        FROM information_schema.table_constraints AS tc
        JOIN information_schema.key_column_usage AS kcu
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
        WHERE tc.constraint_type = 'PRIMARY KEY'
          AND tc.table_schema = $1
          AND tc.table_name = $2
        ORDER BY kcu.ordinal_position
        """
        let rows = try await client.withConnection { conn in
            try await conn.queryPreparedRows(sql, binds: [PGData(string: schema), PGData(string: table)])
        }
        var name: String?
        var cols: [String] = []
        for row in rows {
            let (n, c) = try row.decode((String, String).self)
            name = n
            cols.append(c)
        }
        if let name { return PrimaryKey(name: name, columns: cols) }
        return nil
    }

    public struct ForeignKey: Sendable {
        public let name: String
        public let columns: [String]
        public let referencedSchema: String
        public let referencedTable: String
        public let referencedColumns: [String]
        public let onUpdate: String?
        public let onDelete: String?
    }

    public func foreignKeys(using client: PostgresDatabaseClient, schema: String, table: String) async throws -> [ForeignKey] {
        struct Row { let name: String; let column: String; let refSchema: String; let refTable: String; let refColumn: String; let onUpdate: String?; let onDelete: String?; let position: Int }
        let sql = """
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
        ORDER BY tc.constraint_name, kcu.ordinal_position
        """
        let rows = try await client.withConnection { conn in
            try await conn.queryPreparedRows(sql, binds: [PGData(string: schema), PGData(string: table)])
        }
        var fks: [String: [Row]] = [:]
        for row in rows {
            let (name, column, refSchema, refTable, refColumn, onUpdate, onDelete, position) = try row.decode((String, String, String, String, String, String?, String?, Int).self)
            fks[name, default: []].append(Row(name: name, column: column, refSchema: refSchema, refTable: refTable, refColumn: refColumn, onUpdate: onUpdate, onDelete: onDelete, position: position))
        }
        return fks.sorted { $0.key < $1.key }.map { name, rows in
            let sorted = rows.sorted { $0.position < $1.position }
            return ForeignKey(name: name, columns: sorted.map { $0.column }, referencedSchema: sorted.first!.refSchema, referencedTable: sorted.first!.refTable, referencedColumns: sorted.map { $0.refColumn }, onUpdate: sorted.first!.onUpdate, onDelete: sorted.first!.onDelete)
        }
    }

    public func viewDefinition(using client: PostgresDatabaseClient, schema: String, view: String) async throws -> String? {
        let sql = "SELECT pg_get_viewdef(format('%I.%I', $1, $2)::regclass, true)"
        let rows = try await client.withConnection { conn in
            try await conn.queryPreparedRows(sql, binds: [PGData(string: schema), PGData(string: view)])
        }
        for row in rows { return try row.decode(String?.self) }
        return nil
    }

    public func functionDefinition(using client: PostgresDatabaseClient, schema: String, name: String) async throws -> String? {
        let sql = """
        SELECT pg_catalog.pg_get_functiondef(p.oid)
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = $1 AND p.proname = $2
        ORDER BY p.oid
        LIMIT 1
        """
        let rows = try await client.withConnection { conn in
            try await conn.queryPreparedRows(sql, binds: [PGData(string: schema), PGData(string: name)])
        }
        for row in rows { return try row.decode(String?.self) }
        return nil
    }

    public func triggerDefinition(using client: PostgresDatabaseClient, schema: String, name: String) async throws -> String? {
        let sql = """
        SELECT pg_catalog.pg_get_triggerdef(t.oid, true)
        FROM pg_trigger t
        JOIN pg_class c ON c.oid = t.tgrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = $1 AND t.tgname = $2
        ORDER BY t.oid
        LIMIT 1
        """
        let rows = try await client.withConnection { conn in
            try await conn.queryPreparedRows(sql, binds: [PGData(string: schema), PGData(string: name)])
        }
        for row in rows { return try row.decode(String?.self) }
        return nil
    }

    public struct UniqueConstraint: Sendable {
        public let name: String
        public let columns: [String]
    }

    public func uniqueConstraints(using client: PostgresDatabaseClient, schema: String, table: String) async throws -> [UniqueConstraint] {
        let sql = """
        SELECT tc.constraint_name, kcu.column_name, kcu.ordinal_position
        FROM information_schema.table_constraints AS tc
        JOIN information_schema.key_column_usage AS kcu
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
        WHERE tc.constraint_type = 'UNIQUE'
          AND tc.table_schema = $1
          AND tc.table_name = $2
        ORDER BY tc.constraint_name, kcu.ordinal_position
        """
        let rows = try await client.withConnection { conn in
            try await conn.queryPreparedRows(sql, binds: [PGData(string: schema), PGData(string: table)])
        }
        var map: [String: [String]] = [:]
        for row in rows {
            let (name, column, _): (String, String, Int) = try row.decode((String, String, Int).self)
            map[name, default: []].append(column)
        }
        return map.sorted { $0.key < $1.key }.map { UniqueConstraint(name: $0.key, columns: $0.value) }
    }

    public struct Dependency: Sendable {
        public let name: String
        public let sourceTable: String
        public let referencingColumns: [String]
        public let referencedColumns: [String]
        public let onUpdate: String?
        public let onDelete: String?
    }

    public func dependencies(using client: PostgresDatabaseClient, schema: String, table: String) async throws -> [Dependency] {
        let sql = """
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
        ORDER BY tc.constraint_name, kcu.ordinal_position
        """
        let rows = try await client.withConnection { conn in
            try await conn.queryPreparedRows(sql, binds: [PGData(string: schema), PGData(string: table)])
        }
        struct Row { let name: String; let srcSchema: String; let srcTable: String; let srcColumn: String; let tgtColumn: String; let onUpdate: String?; let onDelete: String?; let pos: Int }
        var map: [String: [Row]] = [:]
        for row in rows {
            let (name, sourceSchema, sourceTable, sourceColumn, targetColumn, onUpdate, onDelete, position) = try row.decode((String, String, String, String, String, String?, String?, Int).self)
            map[name, default: []].append(Row(name: name, srcSchema: sourceSchema, srcTable: sourceTable, srcColumn: sourceColumn, tgtColumn: targetColumn, onUpdate: onUpdate, onDelete: onDelete, pos: position))
        }
        return map.sorted { $0.key < $1.key }.map { name, rows in
            let sorted = rows.sorted { $0.pos < $1.pos }
            let srcTable = sorted.first.map { r in r.srcSchema == schema ? r.srcTable : "\(r.srcSchema).\(r.srcTable)" } ?? ""
            return Dependency(name: name, sourceTable: srcTable, referencingColumns: sorted.map { $0.srcColumn }, referencedColumns: sorted.map { $0.tgtColumn }, onUpdate: sorted.first?.onUpdate, onDelete: sorted.first?.onDelete)
        }
    }

    // Consolidated per-schema column details across tables/views/materialized views.
    public func columnsByTable(using client: PostgresDatabaseClient, schema: String) async throws -> [String: [ColumnDetail]] {
        struct ColRec { let name: String; let type: String; let nullable: Bool; let maxLength: Int?; let ordinal: Int }

        // information_schema columns: prepared path, with safe text casts for
        // fields that previously exhibited format mismatches.
        var columnsByTable: [String: [ColRec]] = [:]
        do {
            let sql = """
                SELECT
                    table_name,
                    column_name,
                    data_type,
                    is_nullable::text,
                    character_maximum_length::text,
                    ordinal_position::text
                FROM information_schema.columns
                WHERE table_schema = $1
                ORDER BY table_name, ordinal_position;
                """
            let rows = try await client.withConnection { conn in
                try await conn.queryPreparedRows(sql, binds: [PGData(string: schema)])
            }
            for row in rows {
                let (table, column, dataType, nullableText, maxLenText, ordinalText) = try row.decode((String, String, String, String, String?, String).self)
                let isNullable = nullableText.uppercased() == "YES" || nullableText.uppercased() == "TRUE" || nullableText == "1"
                let maxLen = maxLenText.flatMap { Int($0) }
                let ordinal = Int(ordinalText) ?? 0
                var list = columnsByTable[table, default: []]
                list.append(ColRec(name: column, type: dataType, nullable: isNullable, maxLength: maxLen, ordinal: ordinal))
                columnsByTable[table] = list
            }
        }

        // primary keys across schema
        let pkRows = try await client.withConnection { conn in
            try await conn.queryPreparedRows(
                """
                SELECT tc.table_name, kcu.column_name
                FROM information_schema.table_constraints AS tc
                JOIN information_schema.key_column_usage AS kcu
                  ON tc.constraint_name = kcu.constraint_name
                  AND tc.table_schema = kcu.table_schema
                WHERE tc.constraint_type = 'PRIMARY KEY'
                  AND tc.table_schema = $1;
                """,
                binds: [PGData(string: schema)]
            )
        }
        var primaryKeysByTable: [String: Set<String>] = [:]
        for row in pkRows {
            let (table, column) = try row.decode((String, String).self)
            var set = primaryKeysByTable[table, default: []]
            set.insert(column)
            primaryKeysByTable[table] = set
        }

        // foreign keys across schema
        let fkRows = try await client.withConnection { conn in
            try await conn.queryPreparedRows(
                """
                SELECT cls.relname AS table_name,
                       att.attname AS column_name,
                       nsp_ref.nspname AS ref_schema,
                       cls_ref.relname AS ref_table,
                       att_ref.attname AS ref_column,
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
                """,
                binds: [PGData(string: schema)]
            )
        }
        var foreignKeysByTable: [String: [String: ColumnDetail.ForeignKeyRef]] = [:]
        for row in fkRows {
            let (table, column, refSchema, refTable, refColumn, conname) = try row.decode((String, String, String, String, String, String).self)
            var tableMap = foreignKeysByTable[table, default: [:]]
            tableMap[column] = ColumnDetail.ForeignKeyRef(constraintName: conname, referencedSchema: refSchema, referencedTable: refTable, referencedColumn: refColumn)
            foreignKeysByTable[table] = tableMap
        }

        // materialized views columns (not always in information_schema)
        do {
            let sql = """
                SELECT
                    c.relname,
                    a.attname,
                    pg_catalog.format_type(a.atttypid, a.atttypmod),
                    (NOT a.attnotnull)::text,
                    NULL::text,
                    a.attnum::text
                FROM pg_attribute a
                JOIN pg_class c ON c.oid = a.attrelid
                JOIN pg_namespace n ON n.oid = c.relnamespace
                WHERE n.nspname = $1
                  AND c.relkind = 'm'
                  AND a.attnum > 0
                  AND NOT a.attisdropped
                ORDER BY c.relname, a.attnum;
                """
            let rows = try await client.withConnection { conn in
                try await conn.queryPreparedRows(sql, binds: [PGData(string: schema)])
            }
            for row in rows {
                let (table, column, dataType, nullableText, _maxLenText, ordinalText) = try row.decode((String, String, String, String, String?, String).self)
                let isNullable = nullableText.uppercased().hasPrefix("T") || nullableText == "1"
                let ordinal = Int(ordinalText) ?? 0
                var list = columnsByTable[table, default: []]
                list.append(ColRec(name: column, type: dataType, nullable: isNullable, maxLength: nil, ordinal: ordinal))
                columnsByTable[table] = list
            }
        }

        // assemble final structure per table
        var result: [String: [ColumnDetail]] = [:]
        for (table, recs) in columnsByTable {
            let sorted = recs.sorted { $0.ordinal < $1.ordinal }
            let pkset = primaryKeysByTable[table] ?? []
            let fks = foreignKeysByTable[table] ?? [:]
            result[table] = sorted.map { r in
                ColumnDetail(
                    name: r.name,
                    dataType: r.type,
                    isNullable: r.nullable,
                    maxLength: r.maxLength,
                    isPrimaryKey: pkset.contains(r.name),
                    foreignKey: fks[r.name]
                )
            }
        }
        return result
    }

    // MARK: - Schema Summary

    public enum SummaryObjectType: String, Sendable {
        case table = "BASE TABLE"
        case view = "VIEW"
        case materializedView = "MATERIALIZED VIEW"
        case function = "FUNCTION"
        case trigger = "TRIGGER"
    }

    public struct SchemaSummary: Sendable {
        public struct Object: Sendable {
            public let name: String
            public let type: SummaryObjectType
            public let columns: [ColumnDetail]
            public let triggerAction: String?
            public let triggerTable: String?
        }
        public let schema: String
        public let objects: [Object]
    }

    public func schemaSummary(
        using client: PostgresDatabaseClient,
        schema: String,
        progress: (@Sendable (SummaryObjectType, Int, Int) async -> Void)? = nil
    ) async throws -> SchemaSummary {
        let columnsByObject = try await columnsByTable(using: client, schema: schema)

        // Tables and views
        let tableSQL = """
        SELECT table_name, table_type
        FROM information_schema.tables
        WHERE table_schema = $1
          AND table_type IN ('BASE TABLE', 'VIEW')
        ORDER BY table_type, table_name;
        """
        let tableRows = try await client.withConnection { conn in
            try await conn.queryPreparedRows(tableSQL, binds: [PGData(string: schema)])
        }
        var entries: [(String, SummaryObjectType)] = []
        for row in tableRows {
            let (name, rawType) = try row.decode((String, String).self)
            let type: SummaryObjectType = rawType.uppercased() == "VIEW" ? .view : .table
            entries.append((name, type))
        }

        // Materialized views
        let matSQL = """
        SELECT matviewname FROM pg_matviews WHERE schemaname = $1 ORDER BY matviewname;
        """
        let matRows = try await client.withConnection { conn in
            try await conn.queryPreparedRows(matSQL, binds: [PGData(string: schema)])
        }
        let matNames: [String] = try matRows.map { try $0.decode(String.self) }

        // Functions
        let funcSQL = """
        SELECT routine_name
        FROM information_schema.routines
        WHERE specific_schema = $1
          AND routine_type = 'FUNCTION'
        ORDER BY routine_name;
        """
        let fnRows = try await client.withConnection { conn in
            try await conn.queryPreparedRows(funcSQL, binds: [PGData(string: schema)])
        }
        let functionNames: [String] = try fnRows.map { try $0.decode(String.self) }

        // Triggers
        let trigSQL = """
        SELECT trigger_name, action_timing, event_manipulation, event_object_table
        FROM information_schema.triggers
        WHERE trigger_schema = $1
        ORDER BY trigger_name;
        """
        let trigRows = try await client.withConnection { conn in
            try await conn.queryPreparedRows(trigSQL, binds: [PGData(string: schema)])
        }
        var triggerEntries: [(String, String, String, String)] = []
        for row in trigRows {
            triggerEntries.append(try row.decode((String, String, String, String).self))
        }

        // Assemble objects
        let total = max(entries.count + matNames.count + functionNames.count + triggerEntries.count, 1)
        var processed = 0
        var objects: [SchemaSummary.Object] = []

        if let progress { await progress(.table, processed, total) }
        for (name, type) in entries {
            processed += 1
            if let progress { await progress(type, processed, total) }
            let cols = columnsByObject[name] ?? []
            objects.append(.init(name: name, type: type, columns: cols, triggerAction: nil, triggerTable: nil))
        }

        if !matNames.isEmpty {
            if let progress { await progress(.materializedView, processed, total) }
            for name in matNames {
                processed += 1
                if let progress { await progress(.materializedView, processed, total) }
                let cols = columnsByObject[name] ?? []
                objects.append(.init(name: name, type: .materializedView, columns: cols, triggerAction: nil, triggerTable: nil))
            }
        }

        if !functionNames.isEmpty {
            if let progress { await progress(.function, processed, total) }
            for name in functionNames {
                processed += 1
                if let progress { await progress(.function, processed, total) }
                objects.append(.init(name: name, type: .function, columns: [], triggerAction: nil, triggerTable: nil))
            }
        }

        if !triggerEntries.isEmpty {
            if let progress { await progress(.trigger, processed, total) }
            for (name, timing, action, table) in triggerEntries {
                processed += 1
                if let progress { await progress(.trigger, processed, total) }
                let actionDisplay = "\(timing.uppercased()) \(action.uppercased())".trimmingCharacters(in: .whitespaces)
                objects.append(.init(name: name, type: .trigger, columns: [], triggerAction: actionDisplay, triggerTable: "\(schema).\(table)"))
            }
        }

        return SchemaSummary(schema: schema, objects: objects)
    }

    // MARK: - Admin Details

    public struct Role: Sendable {
        public let name: String
        public let canLogin: Bool
        public let isSuperuser: Bool
        public let inherits: Bool
        public let createDB: Bool
        public let createRole: Bool
        public let replication: Bool
        public let bypassRLS: Bool
    }

    public func listRoles(using client: PostgresDatabaseClient) async throws -> [Role] {
        let rows = try await client.simpleQuery("""
        SELECT rolname, rolcanlogin, rolsuper, rolinherit, rolcreatedb, rolcreaterole, rolreplication, rolbypassrls
        FROM pg_roles
        ORDER BY rolname
        """)
        var out: [Role] = []
        for try await (name, canLogin, isSuperuser, inherits, createDB, createRole, replication, bypassRLS) in rows.decode((String, Bool, Bool, Bool, Bool, Bool, Bool, Bool).self) {
            out.append(Role(name: name, canLogin: canLogin, isSuperuser: isSuperuser, inherits: inherits, createDB: createDB, createRole: createRole, replication: replication, bypassRLS: bypassRLS))
        }
        return out
    }

    public struct ExtensionInfo: Sendable {
        public let name: String
        public let schema: String
        public let version: String
        public let relocatable: Bool
    }

    public func listExtensions(using client: PostgresDatabaseClient) async throws -> [ExtensionInfo] {
        let rows = try await client.simpleQuery("""
        SELECT e.extname, n.nspname AS schema, e.extversion, e.extrelocatable
        FROM pg_extension e
        JOIN pg_namespace n ON n.oid = e.extnamespace
        ORDER BY e.extname
        """)
        var out: [ExtensionInfo] = []
        for try await (name, schema, version, reloc) in rows.decode((String, String, String, Bool).self) {
            out.append(ExtensionInfo(name: name, schema: schema, version: version, relocatable: reloc))
        }
        return out
    }

    public func tableComment(using client: PostgresDatabaseClient, schema: String, table: String) async throws -> String? {
        let rows = try await client.withConnection { conn in
            try await conn.queryPreparedRows("SELECT obj_description(format('%I.%I', $1, $2)::regclass, 'pg_class')", binds: [PGData(string: schema), PGData(string: table)])
        }
        for row in rows { return try row.decode(String?.self) }
        return nil
    }

    public func viewComment(using client: PostgresDatabaseClient, schema: String, name: String) async throws -> String? {
        try await tableComment(using: client, schema: schema, table: name)
    }

    public func materializedViewComment(using client: PostgresDatabaseClient, schema: String, name: String) async throws -> String? {
        try await tableComment(using: client, schema: schema, table: name)
    }

    public struct ColumnComment: Sendable {
        public let column: String
        public let comment: String?
    }

    public func columnComments(using client: PostgresDatabaseClient, schema: String, table: String) async throws -> [ColumnComment] {
        let rows = try await client.withConnection { conn in
            try await conn.queryPreparedRows(
                """
                SELECT a.attname, col_description(c.oid, a.attnum)
                FROM pg_class c
                JOIN pg_namespace n ON n.oid = c.relnamespace
                JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
                WHERE n.nspname = $1 AND c.relname = $2
                ORDER BY a.attnum
                """,
                binds: [PGData(string: schema), PGData(string: table)]
            )
        }
        var out: [ColumnComment] = []
        for row in rows {
            let (name, comment) = try row.decode((String, String?).self)
            out.append(ColumnComment(column: name, comment: comment))
        }
        return out
    }

    public func functionComment(using client: PostgresDatabaseClient, schema: String, name: String) async throws -> String? {
        let rows = try await client.withConnection { conn in
            try await conn.queryPreparedRows(
                """
                SELECT obj_description(p.oid, 'pg_proc')
                FROM pg_proc p
                JOIN pg_namespace n ON n.oid = p.pronamespace
                WHERE n.nspname = $1 AND p.proname = $2
                ORDER BY p.oid
                LIMIT 1
                """,
                binds: [PGData(string: schema), PGData(string: name)]
            )
        }
        for row in rows { return try row.decode(String?.self) }
        return nil
    }

    public func triggerComment(using client: PostgresDatabaseClient, schema: String, name: String) async throws -> String? {
        let rows = try await client.withConnection { conn in
            try await conn.queryPreparedRows(
                """
                SELECT obj_description(t.oid, 'pg_trigger')
                FROM pg_trigger t
                JOIN pg_class c ON c.oid = t.tgrelid
                JOIN pg_namespace n ON n.oid = c.relnamespace
                WHERE n.nspname = $1 AND t.tgname = $2
                ORDER BY t.oid
                LIMIT 1
                """,
                binds: [PGData(string: schema), PGData(string: name)]
            )
        }
        for row in rows { return try row.decode(String?.self) }
        return nil
    }

    public func databaseComment(using client: PostgresDatabaseClient) async throws -> String? {
        let rows = try await client.simpleQuery("""
        SELECT obj_description(d.oid, 'pg_database')
        FROM pg_database d
        WHERE d.datname = current_database()
        LIMIT 1
        """)
        for try await value in rows.decode(String?.self) { return value }
        return nil
    }
}
