import Foundation

/// The statement a procedure's Execute opens in a new query tab: the call with one line per
/// parameter to fill in (round 42.5, EX1).
nonisolated enum ExecuteStatementBuilder {
    static func sql(qualifiedName: String, parameters: [ProcedureParameterInfo], databaseType: DatabaseType) -> String {
        let inputs = parameters.sorted { $0.ordinalPosition < $1.ordinalPosition }.filter { $0.name != "" }
        switch databaseType {
        case .microsoftSQL:
            guard !inputs.isEmpty else { return "EXEC \(qualifiedName);" }
            let lines = inputs.enumerated().map { index, parameter in
                let separator = index == inputs.count - 1 ? ";" : ","
                let output = parameter.isOutput ? " OUTPUT" : ""
                let hint = parameter.hasDefaultValue ? "\(parameter.dataType), optional" : parameter.dataType
                return "    \(parameter.name) = NULL\(output)\(separator) -- \(hint)"
            }
            return "EXEC \(qualifiedName)\n" + lines.joined(separator: "\n")
        case .postgresql:
            guard !inputs.isEmpty else { return "SELECT * FROM \(qualifiedName)();" }
            let lines = inputs.enumerated().map { index, parameter in
                let separator = index == inputs.count - 1 ? "" : ","
                return "    \(parameter.name) => NULL\(separator) -- \(parameter.dataType)"
            }
            return "SELECT * FROM \(qualifiedName)(\n" + lines.joined(separator: "\n") + "\n);"
        case .mysql, .sqlite:
            guard !inputs.isEmpty else { return "CALL \(qualifiedName)();" }
            let lines = inputs.enumerated().map { index, parameter in
                let separator = index == inputs.count - 1 ? "" : ","
                return "    NULL\(separator) -- \(parameter.name) \(parameter.dataType)"
            }
            return "CALL \(qualifiedName)(\n" + lines.joined(separator: "\n") + "\n);"
        }
    }
}
