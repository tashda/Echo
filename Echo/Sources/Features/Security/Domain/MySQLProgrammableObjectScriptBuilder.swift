import Foundation

enum MySQLProgrammableObjectScriptBuilder {
    struct RoutineDraft: Sendable, Equatable {
        enum Kind: String, CaseIterable, Sendable {
            case function = "Function"
            case procedure = "Procedure"
        }

        var kind: Kind
        var schema: String
        var name: String
        var parameters: String
        var returnType: String
        var deterministic: Bool
        var sqlSecurity: String
        var body: String
    }

    struct TriggerDraft: Sendable, Equatable {
        var schema: String
        var name: String
        var tableName: String
        var timing: String
        var event: String
        var body: String
    }

    struct EventDraft: Sendable, Equatable {
        var schema: String
        var name: String
        var schedule: String
        var preserve: Bool
        var enabled: Bool
        var body: String
    }

    static func createScript(for draft: RoutineDraft) -> String {
        let qualified = "\(quoteIdentifier(draft.schema)).\(quoteIdentifier(draft.name))"
        let parameters = draft.parameters.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = normalizedBody(draft.body)

        var lines = ["DELIMITER $$", ""]
        switch draft.kind {
        case .function:
            let returns = draft.returnType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "TEXT" : draft.returnType.trimmingCharacters(in: .whitespacesAndNewlines)
            lines.append("CREATE FUNCTION \(qualified)(\(parameters))")
            lines.append("RETURNS \(returns)")
        case .procedure:
            lines.append("CREATE PROCEDURE \(qualified)(\(parameters))")
        }

        if draft.kind == .function, draft.deterministic {
            lines.append("DETERMINISTIC")
        }

        let sqlSecurity = draft.sqlSecurity.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !sqlSecurity.isEmpty {
            lines.append("SQL SECURITY \(sqlSecurity)")
        }

        lines.append("BEGIN")
        lines.append(body)
        lines.append("END$$")
        lines.append("")
        lines.append("DELIMITER ;")
        return lines.joined(separator: "\n")
    }

    static func dropScript(kind: RoutineDraft.Kind, schema: String, name: String) -> String {
        let qualified = "\(quoteIdentifier(schema)).\(quoteIdentifier(name))"
        switch kind {
        case .function:
            return "DROP FUNCTION IF EXISTS \(qualified);"
        case .procedure:
            return "DROP PROCEDURE IF EXISTS \(qualified);"
        }
    }

    static func createScript(for draft: TriggerDraft) -> String {
        let qualified = "\(quoteIdentifier(draft.schema)).\(quoteIdentifier(draft.name))"
        let table = "\(quoteIdentifier(draft.schema)).\(quoteIdentifier(draft.tableName))"
        let body = normalizedBody(draft.body)
        return """
        DELIMITER $$

        CREATE TRIGGER \(qualified)
        \(draft.timing.uppercased()) \(draft.event.uppercased()) ON \(table)
        FOR EACH ROW
        BEGIN
        \(body)
        END$$

        DELIMITER ;
        """
    }

    static func dropTriggerScript(schema: String, name: String) -> String {
        "DROP TRIGGER IF EXISTS \(quoteIdentifier(schema)).\(quoteIdentifier(name));"
    }

    static func createScript(for draft: EventDraft) -> String {
        let qualified = "\(quoteIdentifier(draft.schema)).\(quoteIdentifier(draft.name))"
        let schedule = draft.schedule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "EVERY 1 DAY" : draft.schedule.trimmingCharacters(in: .whitespacesAndNewlines)
        let completion = draft.preserve ? "ON COMPLETION PRESERVE" : "ON COMPLETION NOT PRESERVE"
        let status = draft.enabled ? "ENABLE" : "DISABLE"
        let body = normalizedBody(draft.body)
        return """
        DELIMITER $$

        CREATE EVENT \(qualified)
        ON SCHEDULE \(schedule)
        \(completion)
        \(status)
        DO
        BEGIN
        \(body)
        END$$

        DELIMITER ;
        """
    }

    static func dropEventScript(schema: String, name: String) -> String {
        "DROP EVENT IF EXISTS \(quoteIdentifier(schema)).\(quoteIdentifier(name));"
    }

    private static func quoteIdentifier(_ identifier: String) -> String {
        "`\(identifier.replacingOccurrences(of: "`", with: "``"))`"
    }

    private static func normalizedBody(_ body: String) -> String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "    -- Add SQL here" }
        return trimmed
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { "    \($0)" }
            .joined(separator: "\n")
    }
}
