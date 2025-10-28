import Foundation

/// Centralized builders for Postgres catalog search SQL used by Echo.
/// These produce the same results as the inline SQL in Echo but keep
/// the statements in one place for maintainability and future tuning.
public enum PostgresSearchSQL {
    private static let excludedSchemasList = "'pg_catalog','information_schema'"

    public static func makeLikePattern(_ query: String) -> String {
        var sanitized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.replacingOccurrences(of: "\\", with: "\\\\")
        sanitized = sanitized.replacingOccurrences(of: "%", with: "\\%")
        sanitized = sanitized.replacingOccurrences(of: "_", with: "\\_")
        sanitized = sanitized.replacingOccurrences(of: "'", with: "''")
        return sanitized
    }

    public static func tables(pattern: String, limit: Int) -> String {
        """
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE table_type = 'BASE TABLE'
          AND table_schema NOT IN (\(excludedSchemasList))
          AND table_name ILIKE '%\(pattern)%' ESCAPE '\\'
        ORDER BY table_schema, table_name
        LIMIT \(limit);
        """
    }

    public static func views(pattern: String, limit: Int) -> String {
        """
        SELECT table_schema, table_name, view_definition
        FROM information_schema.views
        WHERE (
            table_name ILIKE '%\(pattern)%' ESCAPE '\\'
            OR COALESCE(view_definition, '') ILIKE '%\(pattern)%' ESCAPE '\\'
        )
        ORDER BY table_schema, table_name
        LIMIT \(limit);
        """
    }

    public static func materializedViews(pattern: String, limit: Int) -> String {
        """
        SELECT schemaname, matviewname, definition
        FROM pg_matviews
        WHERE (
            matviewname ILIKE '%\(pattern)%' ESCAPE '\\'
            OR COALESCE(definition, '') ILIKE '%\(pattern)%' ESCAPE '\\'
        )
        ORDER BY schemaname, matviewname
        LIMIT \(limit);
        """
    }

    public static func functions(pattern: String, limit: Int) -> String {
        """
        SELECT routine_schema, routine_name, routine_definition
        FROM information_schema.routines
        WHERE routine_type = 'FUNCTION'
          AND routine_schema NOT IN (\(excludedSchemasList))
          AND (
            routine_name ILIKE '%\(pattern)%' ESCAPE '\\'
            OR COALESCE(routine_definition, '') ILIKE '%\(pattern)%' ESCAPE '\\'
          )
        ORDER BY routine_schema, routine_name
        LIMIT \(limit);
        """
    }

    public static func procedures(pattern: String, limit: Int) -> String {
        """
        SELECT routine_schema, routine_name, routine_definition
        FROM information_schema.routines
        WHERE routine_type = 'PROCEDURE'
          AND routine_schema NOT IN (\(excludedSchemasList))
          AND (
            routine_name ILIKE '%\(pattern)%' ESCAPE '\\'
            OR COALESCE(routine_definition, '') ILIKE '%\(pattern)%' ESCAPE '\\'
          )
        ORDER BY routine_schema, routine_name
        LIMIT \(limit);
        """
    }

    public static func triggers(pattern: String, limit: Int) -> String {
        """
        SELECT trigger_schema, event_object_table, trigger_name, action_statement
        FROM information_schema.triggers
        WHERE trigger_schema NOT IN (\(excludedSchemasList))
          AND (
            trigger_name ILIKE '%\(pattern)%' ESCAPE '\\'
            OR event_object_table ILIKE '%\(pattern)%' ESCAPE '\\'
            OR COALESCE(action_statement, '') ILIKE '%\(pattern)%' ESCAPE '\\'
          )
        ORDER BY trigger_schema, trigger_name
        LIMIT \(limit);
        """
    }

    public static func columns(pattern: String, limit: Int) -> String {
        """
        SELECT table_schema, table_name, column_name, data_type
        FROM information_schema.columns
        WHERE table_schema NOT IN (\(excludedSchemasList))
          AND column_name ILIKE '%\(pattern)%' ESCAPE '\\'
        ORDER BY table_schema, table_name, ordinal_position
        LIMIT \(limit);
        """
    }

    public static func indexes(pattern: String, limit: Int) -> String {
        """
        SELECT schemaname, tablename, indexname, indexdef
        FROM pg_indexes
        WHERE schemaname NOT IN (\(excludedSchemasList))
          AND (
            indexname ILIKE '%\(pattern)%' ESCAPE '\\'
            OR tablename ILIKE '%\(pattern)%' ESCAPE '\\'
            OR COALESCE(indexdef, '') ILIKE '%\(pattern)%' ESCAPE '\\'
          )
        ORDER BY schemaname, indexname
        LIMIT \(limit);
        """
    }

    public static func foreignKeys(pattern: String, limit: Int) -> String {
        """
        WITH fk_data AS (
            SELECT
                tc.constraint_name,
                tc.table_schema,
                tc.table_name,
                ccu.table_schema AS referenced_schema,
                ccu.table_name AS referenced_table,
                string_agg(kcu.column_name ORDER BY kcu.ordinal_position) AS column_list,
                string_agg(ccu.column_name ORDER BY kcu.ordinal_position) AS referenced_column_list
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
              ON tc.constraint_name = kcu.constraint_name
             AND tc.table_schema = kcu.table_schema
            JOIN information_schema.constraint_column_usage ccu
              ON ccu.constraint_name = tc.constraint_name
             AND ccu.table_schema = tc.table_schema
            WHERE tc.constraint_type = 'FOREIGN KEY'
              AND tc.table_schema NOT IN (\(excludedSchemasList))
            GROUP BY
                tc.constraint_name,
                tc.table_schema,
                tc.table_name,
                ccu.table_schema,
                ccu.table_name
        )
        SELECT
            constraint_name,
            table_schema,
            table_name,
            referenced_schema,
            referenced_table,
            column_list,
            referenced_column_list
        FROM fk_data
        WHERE (
            constraint_name ILIKE '%\(pattern)%' ESCAPE '\\'
            OR table_name ILIKE '%\(pattern)%' ESCAPE '\\'
            OR referenced_table ILIKE '%\(pattern)%' ESCAPE '\\'
        )
        ORDER BY table_schema, table_name, constraint_name
        LIMIT \(limit);
        """
    }
}
