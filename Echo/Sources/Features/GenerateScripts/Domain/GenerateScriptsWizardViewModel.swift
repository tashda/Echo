import Foundation
import Observation
import SQLServerKit
import Logging
import AppKit
import UniformTypeIdentifiers

/// Manages the multi-step Generate Scripts wizard state.
@Observable @MainActor
final class GenerateScriptsWizardViewModel {

    // MARK: - Step Navigation

    enum Step: Int, CaseIterable {
        case selectObjects = 1
        case setOptions = 2
        case output = 3
    }

    var currentStep: Step = .selectObjects

    // MARK: - Step 1: Object Selection

    /// All scriptable objects grouped by category.
    var objectsByCategory: [(category: String, objects: [GenerateScriptsObject])] = []
    /// Set of selected object IDs.
    var selectedObjectIDs: Set<String> = []
    /// Categories with all objects selected (for "Select All" checkboxes).
    var isLoadingObjects = false

    // MARK: - Step 2: Scripting Options

    var scriptMode: SQLServerScriptingOptions.ScriptMode = .schemaOnly
    var includePermissions = false
    var includeTriggers = true
    var includeIndexes = true
    var includeExtendedProperties = false
    var checkExistence = true
    var scriptDropAndCreate = false
    var includeUseDatabase = true

    // MARK: - Step 3: Output

    enum OutputDestination: String, CaseIterable, Identifiable {
        case clipboard = "Clipboard"
        case newQueryWindow = "New Query Window"
        case file = "Save to File"
        var id: String { rawValue }
    }

    var outputDestination: OutputDestination = .newQueryWindow

    // MARK: - Generation State

    var isGenerating = false
    var progress: Double = 0
    var statusMessage = ""
    var generatedScript = ""
    var generationError: String?
    var generationSucceeded = false

    // MARK: - Dependencies

    let session: DatabaseSession
    let databaseName: String
    let databaseType: DatabaseType
    let preferredObjectID: String?
    let logger = Logger(label: "GenerateScriptsWizardViewModel")

    /// Called when the script should be opened in a new query tab.
    var onOpenInQueryTab: ((String) -> Void)?

    init(session: DatabaseSession, databaseName: String, databaseType: DatabaseType, preferredObject: SchemaObjectInfo? = nil) {
        self.session = session
        self.databaseName = databaseName
        self.databaseType = databaseType
        self.preferredObjectID = preferredObject.map { GenerateScriptsObject($0).id }
    }

    // MARK: - Navigation

    var canGoNext: Bool {
        switch currentStep {
        case .selectObjects: return !selectedObjectIDs.isEmpty
        case .setOptions: return true
        case .output: return true
        }
    }

    func nextStep() {
        if let next = Step(rawValue: currentStep.rawValue + 1) {
            currentStep = next
        }
    }

    func previousStep() {
        if let prev = Step(rawValue: currentStep.rawValue - 1) {
            currentStep = prev
        }
    }

    // MARK: - Object Selection Helpers

    func isAllSelected(in category: String) -> Bool {
        guard let group = objectsByCategory.first(where: { $0.category == category }) else { return false }
        return group.objects.allSatisfy { selectedObjectIDs.contains($0.id) }
    }

    func toggleAll(in category: String) {
        guard let group = objectsByCategory.first(where: { $0.category == category }) else { return }
        if isAllSelected(in: category) {
            for obj in group.objects { selectedObjectIDs.remove(obj.id) }
        } else {
            for obj in group.objects { selectedObjectIDs.insert(obj.id) }
        }
    }

    func toggleObject(_ obj: GenerateScriptsObject) {
        if selectedObjectIDs.contains(obj.id) {
            selectedObjectIDs.remove(obj.id)
        } else {
            selectedObjectIDs.insert(obj.id)
        }
    }

    func selectAll() {
        for group in objectsByCategory {
            for obj in group.objects { selectedObjectIDs.insert(obj.id) }
        }
    }

    func deselectAll() {
        selectedObjectIDs.removeAll()
    }

    // MARK: - Output Delivery

    func deliverOutput(_ script: String) {
        switch outputDestination {
        case .clipboard:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(script, forType: .string)
        case .newQueryWindow:
            onOpenInQueryTab?(script)
        case .file:
            // File save is handled by the view via NSSavePanel
            break
        }
    }

    func saveToFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "sql")!]
        panel.nameFieldStringValue = "\(databaseName)_script.sql"
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try generatedScript.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                logger.error("Failed to save script file: \(error)")
            }
        }
    }
}
