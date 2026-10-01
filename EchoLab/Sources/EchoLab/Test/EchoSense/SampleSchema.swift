import EchoSense
import Foundation

/// A small sales database for trying completions without a server. Live schemas from a
/// connection replace it on the Connections page.
enum SampleSchema {
    static func structure(for type: EchoSenseDatabaseType) -> EchoSenseDatabaseStructure {
        let sales = "sales"
        let hr = "hr"
        func column(_ name: String, _ type: String, pk: Bool = false, nullable: Bool = true,
                    references: (String, String, String)? = nil) -> EchoSenseColumnInfo {
            EchoSenseColumnInfo(
                name: name, dataType: type, isPrimaryKey: pk, isNullable: nullable,
                foreignKey: references.map {
                    EchoSenseForeignKeyReference(
                        constraintName: "fk_\(name)", referencedSchema: $0.0, referencedTable: $0.1, referencedColumn: $0.2)
                })
        }
        let customers = EchoSenseSchemaObjectInfo(name: "customers", schema: sales, type: .table, columns: [
            column("customer_id", "int", pk: true, nullable: false),
            column("name", "varchar(120)", nullable: false),
            column("email", "varchar(200)"),
            column("country", "varchar(2)"),
            column("created_at", "timestamp", nullable: false),
        ])
        let orders = EchoSenseSchemaObjectInfo(name: "orders", schema: sales, type: .table, columns: [
            column("order_id", "int", pk: true, nullable: false),
            column("customer_id", "int", nullable: false, references: (sales, "customers", "customer_id")),
            column("status", "varchar(20)", nullable: false),
            column("total", "numeric(12,2)", nullable: false),
            column("ordered_at", "timestamp", nullable: false),
        ])
        let items = EchoSenseSchemaObjectInfo(name: "order_items", schema: sales, type: .table, columns: [
            column("order_id", "int", pk: true, nullable: false, references: (sales, "orders", "order_id")),
            column("line", "int", pk: true, nullable: false),
            column("product_id", "int", nullable: false, references: (sales, "products", "product_id")),
            column("quantity", "int", nullable: false),
        ])
        let products = EchoSenseSchemaObjectInfo(name: "products", schema: sales, type: .table, columns: [
            column("product_id", "int", pk: true, nullable: false),
            column("title", "varchar(160)", nullable: false),
            column("price", "numeric(10,2)", nullable: false),
        ])
        let revenue = EchoSenseSchemaObjectInfo(name: "monthly_revenue", schema: sales, type: .view, columns: [
            column("month", "date"), column("revenue", "numeric(14,2)"),
        ])
        let employees = EchoSenseSchemaObjectInfo(name: "employees", schema: hr, type: .table, columns: [
            column("employee_id", "int", pk: true, nullable: false),
            column("full_name", "varchar(120)", nullable: false),
            column("manager_id", "int", references: (hr, "employees", "employee_id")),
        ])
        let database = EchoSenseDatabaseInfo(name: "shop", schemas: [
            EchoSenseSchemaInfo(name: sales, objects: [customers, orders, items, products, revenue]),
            EchoSenseSchemaInfo(name: hr, objects: [employees]),
        ])
        return EchoSenseDatabaseStructure(serverVersion: "sample", databases: [database])
    }

    static let defaultSQL = "SELECT c.name, o.\nFROM sales.customers c\nJOIN sales.orders o ON o.customer_id = c.customer_id\nWHERE "
}
