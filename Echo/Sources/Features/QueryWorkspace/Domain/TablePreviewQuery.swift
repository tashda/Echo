import EchoSense
import Foundation

extension TablePreviewQuery {
    static func sql(schema: String, table: String, databaseType: DatabaseType) -> String {
        sql(schema: schema, table: table, databaseType: EchoSenseDatabaseType(databaseType))
    }

    static func qualifiedName(schema: String, table: String, databaseType: DatabaseType) -> String {
        qualifiedName(schema: schema, table: table, databaseType: EchoSenseDatabaseType(databaseType))
    }
}
