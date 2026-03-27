import Foundation
import Observation

@Observable
final class FunctionEditorViewModel {
    let connectionSessionID: UUID
    let schemaName: String
    let existingFunctionName: String?

    var isEditing: Bool { existingFunctionName != nil }

    // MARK: - Form State

    var functionName = ""
    var language = "plpgsql"
    var returnType = "void"
    var body = ""
    var volatility: FunctionVolatility = .volatile
    var parallelSafety: FunctionParallelSafety = .unsafe
    var securityType: FunctionSecurityType = .invoker
    var isStrict = false
    var cost = "100"
    var estimatedRows = "1000"
    var description = ""
    var parameters: [FunctionParameterDraft] = []

    // MARK: - Loading State

    var isLoading = false
    var isSubmitting = false
    var didComplete = false
    var errorMessage: String?

    // MARK: - ActivityEngine

    @ObservationIgnored var activityEngine: ActivityEngine?

    // MARK: - Dirty Tracking

    @ObservationIgnored private var snapshot: Snapshot?

    struct Snapshot {
        let functionName: String
        let language: String
        let returnType: String
        let body: String
        let volatility: FunctionVolatility
        let parallelSafety: FunctionParallelSafety
        let securityType: FunctionSecurityType
        let isStrict: Bool
        let cost: String
        let estimatedRows: String
        let description: String
        let parameterCount: Int
        let parameterHash: Int
    }

    func takeSnapshot() {
        snapshot = Snapshot(
            functionName: functionName,
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
            parameterCount: parameters.count,
            parameterHash: parameterHash
        )
    }

    private var parameterHash: Int {
        var hasher = Hasher()
        for param in parameters {
            hasher.combine(param.name)
            hasher.combine(param.dataType)
            hasher.combine(param.mode.rawValue)
            hasher.combine(param.defaultValue)
        }
        return hasher.finalize()
    }

    var hasChanges: Bool {
        guard let snapshot else { return !isEditing }
        if functionName != snapshot.functionName { return true }
        if language != snapshot.language { return true }
        if returnType != snapshot.returnType { return true }
        if body != snapshot.body { return true }
        if volatility != snapshot.volatility { return true }
        if parallelSafety != snapshot.parallelSafety { return true }
        if securityType != snapshot.securityType { return true }
        if isStrict != snapshot.isStrict { return true }
        if cost != snapshot.cost { return true }
        if estimatedRows != snapshot.estimatedRows { return true }
        if description != snapshot.description { return true }
        if parameters.count != snapshot.parameterCount { return true }
        if parameterHash != snapshot.parameterHash { return true }
        return false
    }

    // MARK: - Init

    init(connectionSessionID: UUID, schemaName: String, existingFunctionName: String?) {
        self.connectionSessionID = connectionSessionID
        self.schemaName = schemaName
        self.existingFunctionName = existingFunctionName
        if let existingFunctionName {
            self.functionName = existingFunctionName
        }
    }

    // MARK: - Validation

    var isFormValid: Bool {
        let name = functionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !isSubmitting else { return false }
        guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return true
    }

    // MARK: - Pages

    var pages: [FunctionEditorPage] {
        FunctionEditorPage.allCases
    }
}
