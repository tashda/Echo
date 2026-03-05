import Foundation

struct PostgresSearchSQL {
    static func makeLikePattern(_ query: String) -> String {
        var sanitized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.replacingOccurrences(of: "\\", with: "\\\\")
        sanitized = sanitized.replacingOccurrences(of: "%", with: "\\%")
        sanitized = sanitized.replacingOccurrences(of: "_", with: "\\_")
        sanitized = sanitized.replacingOccurrences(of: "'", with: "''")
        return sanitized
    }

    static func tables(pattern: String, limit: Int) -> String {
        return """
        SELECT
            schemaname,
            tablename
        FROM pg_catalog.pg_tables
        WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
          AND tablename ILIKE '%\(pattern)%'
        ORDER BY schemaname, tablename
        LIMIT \(limit);
        """
    }

    static func views(pattern: String, limit: Int) -> String {
        return """
        SELECT
            schemaname,
            viewname,
            definition
        FROM pg_catalog.pg_views
        WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
          AND (
            viewname ILIKE '%\(pattern)%'
            OR definition ILIKE '%\(pattern)%'
          )
        ORDER BY schemaname, viewname
        LIMIT \(limit);
        """
    }

    static func materializedViews(pattern: String, limit: Int) -> String {
        return """
        SELECT
            schemaname,
            matviewname,
            definition
        FROM pg_catalog.pg_matviews
        WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
          AND (
            matviewname ILIKE '%\(pattern)%'
            OR definition ILIKE '%\(pattern)%'
          )
        ORDER BY schemaname, matviewname
        LIMIT \(limit);
        """
    }

    static func functions(pattern: String, limit: Int) -> String {
        return """
        SELECT
            n.nspname AS schema,
            p.proname AS name,
            pg_get_functiondef(p.oid) AS definition
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        LEFT JOIN pg_aggregate a ON a.aggfnoid = p.oid
        WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
          AND a.aggfnoid IS NULL
          AND p.prokind = 'f'
          AND (
            p.proname ILIKE '%\(pattern)%'
            OR pg_get_functiondef(p.oid) ILIKE '%\(pattern)%'
          )
        ORDER BY schema, name
        LIMIT \(limit);
        """
    }

    static func procedures(pattern: String, limit: Int) -> String {
        return """
        SELECT
            n.nspname AS schema,
            p.proname AS name,
            pg_get_functiondef(p.oid) AS definition
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
          AND p.prokind = 'p'
          AND (
            p.proname ILIKE '%\(pattern)%'
            OR pg_get_functiondef(p.oid) ILIKE '%\(pattern)%'
          )
        ORDER BY schema, name
        LIMIT \(limit);
        """
    }

    static func triggers(pattern: String, limit: Int) -> String {
        return """
        SELECT
            n.nspname AS schema,
            c.relname AS table_name,
            t.tgname AS trigger_name,
            pg_get_triggerdef(t.oid) AS definition
        FROM pg_trigger t
        JOIN pg_class c ON c.oid = t.tgrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
          AND NOT t.tgisinternal
          AND (
            t.tgname ILIKE '%\(pattern)%'
            OR c.relname ILIKE '%\(pattern)%'
          )
        ORDER BY schema, trigger_name
        LIMIT \(limit);
        """
    }

    static func columns(pattern: String, limit: Int) -> String {
        return """
        SELECT
            table_schema,
            table_name,
            column_name,
            data_type
        FROM information_schema.columns
        WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
          AND column_name ILIKE '%\(pattern)%'
        ORDER BY table_schema, table_name, ordinal_position
        LIMIT \(limit);
        """
    }

    static func indexes(pattern: String, limit: Int) -> String {
        return """
        SELECT
            schemaname,
            tablename,
            indexname,
            indexdef
        FROM pg_indexes
        WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
          AND (
            indexname ILIKE '%\(pattern)%'
            OR tablename ILIKE '%\(pattern)%'
          )
        ORDER BY schemaname, indexname
        LIMIT \(limit);
        """
    }

    static func foreignKeys(pattern: String, limit: Int) -> String {
        return """
        SELECT
            tc.constraint_name,
            tc.table_schema,
            tc.table_name,
            ccu.table_schema AS foreign_table_schema,
            ccu.table_name AS foreign_table_name,
            STRING_AGG(kcu.column_name, ', ') AS columns,
            STRING_AGG(ccu.column_name, ', ') AS foreign_columns
        FROM information_schema.table_constraints AS tc
        JOIN information_schema.key_column_usage AS kcu
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
        JOIN information_schema.constraint_column_usage AS ccu
          ON ccu.constraint_name = tc.constraint_name
          AND ccu.table_schema = tc.table_schema
        WHERE tc.constraint_type = 'FOREIGN KEY'
          AND tc.table_schema NOT IN ('pg_catalog', 'information_schema')
          AND tc.constraint_name ILIKE '%\(pattern)%'
        GROUP BY tc.constraint_name, tc.table_schema, tc.table_name, ccu.table_schema, ccu.table_name
        ORDER BY tc.table_schema, tc.table_name, tc.constraint_name
        LIMIT \(limit);
        """
    }
}
