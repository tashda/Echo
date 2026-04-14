import OSLog

extension Logger {
    private static let subsystem = "dev.echodb.echo"

    static let connection = Logger(subsystem: subsystem, category: "connection")
    static let mssql = Logger(subsystem: subsystem, category: "mssql")
    static let postgres = Logger(subsystem: subsystem, category: "postgres")
    static let mysql = Logger(subsystem: subsystem, category: "mysql")
    static let sqlite = Logger(subsystem: subsystem, category: "sqlite")
    static let query = Logger(subsystem: subsystem, category: "query")
    static let spool = Logger(subsystem: subsystem, category: "spool")
    static let formatting = Logger(subsystem: subsystem, category: "formatting")
    static let schema = Logger(subsystem: subsystem, category: "schema")
    static let diagram = Logger(subsystem: subsystem, category: "diagram")
    static let fonts = Logger(subsystem: subsystem, category: "fonts")
    static let grid = Logger(subsystem: subsystem, category: "grid")
}
