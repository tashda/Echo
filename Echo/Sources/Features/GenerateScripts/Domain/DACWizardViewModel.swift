import Foundation
import Observation
import SQLServerKit
import Logging

@Observable @MainActor
final class DACWizardViewModel {
    enum Mode {
        case extractDacpac // Schema only
        case deployDacpac  // Update DB from DACPAC
        case exportBacpac  // Schema + Data
        case importBacpac  // Create DB from BACPAC
    }
    
    enum Step: Int, CaseIterable {
        case selectOperation = 1
        case setTarget = 2
        case progress = 3
        case summary = 4
    }
    
    var mode: Mode = .extractDacpac
    var currentStep: Step = .selectOperation
    
    var databaseName: String = ""
    var filePath: String = ""
    
    var isOperating = false
    var progress: Double = 0
    var statusMessage = ""
    var errorMessage: String?
    
    private let session: DatabaseSession
    private let logger = Logger(label: "DACWizardViewModel")
    
    init(session: DatabaseSession, databaseName: String = "") {
        self.session = session
        self.databaseName = databaseName
    }
    
    func runOperation() {
        guard let client = session.dac else { return }
        isOperating = true
        progress = 0
        statusMessage = "Starting operation..."
        errorMessage = nil
        currentStep = .progress
        
        Task {
            do {
                switch mode {
                case .extractDacpac:
                    statusMessage = "Extracting schema..."
                    _ = try await client.extractDacpac(database: databaseName)
                case .deployDacpac:
                    statusMessage = "Deploying package..."
                    // In a real app, we'd read the file from filePath
                    try await client.deployDacpac(data: Data(), targetDatabase: databaseName)
                case .exportBacpac:
                    statusMessage = "Exporting data..."
                    _ = try await client.exportBacpac(database: databaseName)
                case .importBacpac:
                    statusMessage = "Importing data..."
                    // Placeholder for import
                    throw NSError(domain: "DAC", code: -1, userInfo: [NSLocalizedDescriptionKey: "BACPAC import not yet implemented"])
                }
                
                self.statusMessage = "Operation completed successfully."
                self.isOperating = false
                self.currentStep = .summary
            } catch {
                logger.error("DAC operation failed: \(error)")
                self.errorMessage = error.localizedDescription
                self.isOperating = false
                self.statusMessage = "Operation failed."
            }
        }
    }
    
    func nextStep() {
        if let next = Step(rawValue: currentStep.rawValue + 1) {
            currentStep = next
        }
    }
    
    func prevStep() {
        if let prev = Step(rawValue: currentStep.rawValue - 1) {
            currentStep = prev
        }
    }
}
