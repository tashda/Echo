import Testing
@testable import Echo

struct MySQLProgrammableObjectScriptBuilderTests {
    @Test func functionScriptIncludesReturnTypeAndSecurity() {
        let sql = MySQLProgrammableObjectScriptBuilder.createScript(
            for: .init(
                kind: .function,
                schema: "app",
                name: "calculate_total",
                parameters: "IN p_id INT",
                returnType: "DECIMAL(10,2)",
                deterministic: true,
                sqlSecurity: "INVOKER",
                body: "RETURN 0;"
            )
        )

        #expect(sql.contains("CREATE FUNCTION `app`.`calculate_total`(IN p_id INT)"))
        #expect(sql.contains("RETURNS DECIMAL(10,2)"))
        #expect(sql.contains("DETERMINISTIC"))
        #expect(sql.contains("SQL SECURITY INVOKER"))
        #expect(sql.contains("RETURN 0;"))
    }

    @Test func triggerScriptIncludesQualifiedTableAndBody() {
        let sql = MySQLProgrammableObjectScriptBuilder.createScript(
            for: .init(
                schema: "sales",
                name: "orders_before_insert",
                tableName: "orders",
                timing: "BEFORE",
                event: "INSERT",
                body: "SET NEW.created_at = NOW();"
            )
        )

        #expect(sql.contains("CREATE TRIGGER `sales`.`orders_before_insert`"))
        #expect(sql.contains("BEFORE INSERT ON `sales`.`orders`"))
        #expect(sql.contains("SET NEW.created_at = NOW();"))
    }

    @Test func eventScriptIncludesScheduleAndStatus() {
        let sql = MySQLProgrammableObjectScriptBuilder.createScript(
            for: .init(
                schema: "ops",
                name: "nightly_cleanup",
                schedule: "EVERY 1 DAY",
                preserve: true,
                enabled: false,
                body: "DELETE FROM temp_rows;"
            )
        )

        #expect(sql.contains("CREATE EVENT `ops`.`nightly_cleanup`"))
        #expect(sql.contains("ON SCHEDULE EVERY 1 DAY"))
        #expect(sql.contains("ON COMPLETION PRESERVE"))
        #expect(sql.contains("DISABLE"))
        #expect(sql.contains("DELETE FROM temp_rows;"))
    }

    @Test func dropScriptsUseQualifiedNames() {
        #expect(
            MySQLProgrammableObjectScriptBuilder.dropScript(kind: .procedure, schema: "app", name: "refresh_summary")
                == "DROP PROCEDURE IF EXISTS `app`.`refresh_summary`;"
        )
        #expect(
            MySQLProgrammableObjectScriptBuilder.dropTriggerScript(schema: "app", name: "orders_audit")
                == "DROP TRIGGER IF EXISTS `app`.`orders_audit`;"
        )
        #expect(
            MySQLProgrammableObjectScriptBuilder.dropEventScript(schema: "app", name: "nightly")
                == "DROP EVENT IF EXISTS `app`.`nightly`;"
        )
    }
}
