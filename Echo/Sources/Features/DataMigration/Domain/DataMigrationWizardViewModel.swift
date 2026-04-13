import Foundation
import Observation
import Logging
import AppKit
import UniformTypeIdentifiers

/// Manages the multi-step Data Migration wizard state.
/// Migrates schema and data between two active database connections.
@Observable @MainActor
final class DataMigrationWizardViewModel {

    // MARK: - Step Navigation

    enum Step: Int, CaseIterable {
        case selectSource = 1
        case selectTarget = 2
        case selectObjects = 3
        case options = 4
        case review = 5
    }

    var currentStep: Step = .selectSource

    // MARK: - Step 1: Source Selection

    var availableSessions: [ConnectionSession] = []
    var sourceSessionID: UUID?
    var sourceDatabaseName: String = ""
    var sourceDatabases: [String] = []
    var isLoadingSourceDatabases = false

    // MARK: - Step 2: Target Selection

    var targetSessionID: UUID?
    var targetDatabaseName: String = ""
    var targetDatabases: [String] = []
    var isLoadingTargetDatabases = false

    // MARK: - Step 3: Object Selection

    struct MigrationObject: Identifiable, Hashable {
        let id: String
        let schema: String
        let name: String
        let objectType: String
    }

    var sourceObjects: [MigrationObject] = []
    var selectedObjectIDs: Set<String> = []
    var isLoadingObjects = false

    // MARK: - Step 4: Options

    var migrateSchema = true
    var migrateData = true
    var dropTargetIfExists = false
    var batchSize = 1000
    var continueOnError = true

    // MARK: - Step 5: Review & Execute

    var generatedSQL = ""
    var isGenerating = false
    var isMigrating = false
    var migrationProgress: Double = 0
    var migrationStatus = ""
    var migrationError: String?
    var migrationSucceeded = false
    var migrationLog: [String] = []

    // MARK: - Output

    enum OutputDestination: String, CaseIterable, Identifiable {
        case execute = "Execute Migration"
        case queryTab = "Open in Query Tab"
        case clipboard = "Copy to Clipboard"
        case file = "Save to File"
        var id: String { rawValue }
    }

    var outputDestination: OutputDestination = .queryTab

    // MARK: - Dependencies

    var onOpenInQueryTab: ((String) -> Void)?
    let logger = Logger(label: "DataMigrationWizardViewModel")

    // MARK: - Navigation

    var canGoNext: Bool {
        switch currentStep {
        case .selectSource: return sourceSessionID != nil && !sourceDatabaseName.isEmpty
        case .selectTarget: return targetSessionID != nil && !targetDatabaseName.isEmpty
        case .selectObjects: return !selectedObjectIDs.isEmpty
        case .options: return true
        case .review: return true
        }
    }

    func nextStep() {
        guard let next = Step(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next

        switch next {
        case .selectObjects:
            if sourceObjects.isEmpty { loadSourceObjects() }
        case .review:
            generateMigrationSQL()
        default:
            break
        }
    }

    func previousStep() {
        if let prev = Step(rawValue: currentStep.rawValue - 1) {
            currentStep = prev
        }
    }

    // MARK: - Source/Target Sessions

    var sourceSession: ConnectionSession? {
        guard let id = sourceSessionID else { return nil }
        return availableSessions.first(where: { $0.id == id })
    }

    var targetSession: ConnectionSession? {
        guard let id = targetSessionID else { return nil }
        return availableSessions.first(where: { $0.id == id })
    }
}
