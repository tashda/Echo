import Foundation

extension FunctionEditorViewModel {

    func generateSQL() -> String {
        let context = FunctionEditorSQLContext(
            schema: schemaName,
            name: functionName,
            language: language,
            returnType: returnType,
            body: body,
            volatility: volatility,
            parallelSafety: parallelSafety,
            securityType: securityType,
            isStrict: isStrict,
            cost: cost,
            estimatedRows: estimatedRows,
            description: description,
            parameters: parameters,
            isEditing: isEditing
        )
        return dialect.generateSQL(context: context)
    }

    func apply(session: ConnectionSession) async {
        isSubmitting = true
        errorMessage = nil
        let handle = activityEngine?.begin(
            isEditing ? "Alter function \(functionName)" : "Create function \(functionName)",
            connectionSessionID: connectionSessionID
        )

        do {
            let sql = generateSQL()
            _ = try await session.session.simpleQuery(sql)
            handle?.succeed()
            takeSnapshot()
        } catch {
            let message = "Failed to apply: \(error.localizedDescription)"
            errorMessage = message
            handle?.fail(message)
        }

        isSubmitting = false
    }

    func saveAndClose(session: ConnectionSession) async {
        await apply(session: session)
        if errorMessage == nil {
            didComplete = true
        }
    }
}
