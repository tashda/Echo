import SwiftUI

extension ObjectBrowserSidebarView {
    func creationOptions(for databaseType: DatabaseType) -> [ExplorerCreationMenuItem] {
        switch databaseType {
        case .postgresql:
            return [
                .init(title: "New Table", icon: .system("tablecells")),
                .init(title: "New View", icon: .system("eye")),
                .init(title: "New Materialized View", icon: .system("eye.fill")),
                .init(title: "New Function", icon: .system("function")),
                .init(title: "New Trigger", icon: .system("bolt")),
                .init(title: "New Extension", icon: .system("puzzlepiece")),
                .init(title: "New Schema", icon: .asset("schema"))
            ]
        case .mysql:
            return [
                .init(title: "New Table", icon: .system("tablecells")),
                .init(title: "New View", icon: .system("eye")),
                .init(title: "New Function", icon: .system("function")),
                .init(title: "New Trigger", icon: .system("bolt"))
            ]
        case .microsoftSQL:
            return [
                .init(title: "New Table", icon: .system("tablecells")),
                .init(title: "New View", icon: .system("eye")),
                .init(title: "New Procedure", icon: .system("gearshape")),
                .init(title: "New Function", icon: .system("function")),
                .init(title: "New Trigger", icon: .system("bolt"))
            ]
        case .sqlite:
            return [
                .init(title: "New Table", icon: .system("tablecells")),
                .init(title: "New View", icon: .system("eye"))
            ]
        }
    }

    func creationTemplateSQL(for title: String, databaseType: DatabaseType, schemaName: String?) -> String {
        switch databaseType {
        case .postgresql:
            return postgresCreationTemplate(for: title, schema: schemaName ?? "public")
        case .microsoftSQL:
            return mssqlCreationTemplate(for: title, schema: schemaName ?? "dbo")
        case .mysql:
            return mysqlCreationTemplate(for: title)
        case .sqlite:
            return sqliteCreationTemplate(for: title)
        }
    }

    // MARK: - PostgreSQL Templates

    private func postgresCreationTemplate(for title: String, schema: String) -> String {
        switch title {
        case "New Table":
            return """
            CREATE TABLE \(schema).new_table (
                id SERIAL PRIMARY KEY,
                name TEXT NOT NULL,
                created_at TIMESTAMPTZ DEFAULT NOW()
            );
            """
        case "New View":
            return """
            CREATE OR REPLACE VIEW \(schema).new_view AS
            SELECT * FROM table_name;
            """
        case "New Materialized View":
            return """
            CREATE MATERIALIZED VIEW \(schema).new_matview AS
            SELECT * FROM table_name;
            """
        case "New Function":
            return """
            CREATE OR REPLACE FUNCTION \(schema).new_function()
            RETURNS void
            LANGUAGE plpgsql
            AS $$
            BEGIN
                -- function body
            END;
            $$;
            """
        case "New Procedure":
            return """
            CREATE OR REPLACE PROCEDURE \(schema).new_procedure()
            LANGUAGE plpgsql
            AS $$
            BEGIN
                -- procedure body
            END;
            $$;
            """
        case "New Trigger":
            return """
            CREATE TRIGGER new_trigger
            AFTER INSERT ON table_name
            FOR EACH ROW
            EXECUTE FUNCTION trigger_function();
            """
        case "New Schema":
            return """
            CREATE SCHEMA new_schema;
            """
        default:
            return ""
        }
    }

    // MARK: - MSSQL Templates

    private func mssqlCreationTemplate(for title: String, schema: String) -> String {
        switch title {
        case "New Table":
            return """
            CREATE TABLE [\(schema)].[NewTable] (
                [Id] INT IDENTITY(1,1) PRIMARY KEY,
                [Name] NVARCHAR(255) NOT NULL,
                [CreatedAt] DATETIME2 DEFAULT GETDATE()
            );
            GO
            """
        case "New View":
            return """
            CREATE VIEW [\(schema)].[NewView] AS
            SELECT * FROM [TableName];
            GO
            """
        case "New Function":
            return """
            CREATE FUNCTION [\(schema)].[NewFunction] ()
            RETURNS INT
            AS
            BEGIN
                RETURN 0;
            END;
            GO
            """
        case "New Procedure":
            return """
            CREATE PROCEDURE [\(schema)].[NewProcedure]
            AS
            BEGIN
                SET NOCOUNT ON;
                -- procedure body
            END;
            GO
            """
        case "New Trigger":
            return """
            CREATE TRIGGER [\(schema)].[NewTrigger]
            ON [\(schema)].[TableName]
            AFTER INSERT
            AS
            BEGIN
                SET NOCOUNT ON;
                -- trigger body
            END;
            GO
            """
        default:
            return ""
        }
    }

    // MARK: - MySQL Templates

    private func mysqlCreationTemplate(for title: String) -> String {
        switch title {
        case "New Table":
            return """
            CREATE TABLE new_table (
                id INT AUTO_INCREMENT PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
            """
        case "New View":
            return """
            CREATE OR REPLACE VIEW new_view AS
            SELECT * FROM table_name;
            """
        case "New Function":
            return """
            CREATE FUNCTION new_function()
            RETURNS INT
            DETERMINISTIC
            BEGIN
                RETURN 0;
            END;
            """
        case "New Trigger":
            return """
            CREATE TRIGGER new_trigger
            AFTER INSERT ON table_name
            FOR EACH ROW
            BEGIN
                -- trigger body
            END;
            """
        default:
            return ""
        }
    }

    // MARK: - SQLite Templates

    private func sqliteCreationTemplate(for title: String) -> String {
        switch title {
        case "New Table":
            return """
            CREATE TABLE new_table (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                created_at TEXT DEFAULT (datetime('now'))
            );
            """
        case "New View":
            return """
            CREATE VIEW new_view AS
            SELECT * FROM table_name;
            """
        default:
            return ""
        }
    }
}
