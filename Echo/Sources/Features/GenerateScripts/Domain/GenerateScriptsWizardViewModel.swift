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
    var objectsByCategory: [(category: String, objects: [SQLServerObjectIdentifier])] = []
    /// Set of selected object IDs.
    var selectedObjectIDs: Set<SQLServerObjectIdentifier> = []
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

    private let session: DatabaseSession
    private let databaseName: String
    private let logger = Logger(label: "GenerateScriptsWizardViewModel")

    /// Called when the script should be opened in a new query tab.
    var onOpenInQueryTab: ((String) -> Void)?

    init(session: DatabaseSession, databaseName: String) {
        self.session = session
        self.databaseName = databaseName
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
        return group.objects.allSatisfy { selectedObjectIDs.contains($0) }
    }

    func toggleAll(in category: String) {
        guard let group = objectsByCategory.first(where: { $0.category == category }) else { return }
        if isAllSelected(in: category) {
            for obj in group.objects { selectedObjectIDs.remove(obj) }
        } else {
            for obj in group.objects { selectedObjectIDs.insert(obj) }
        }
    }

    func toggleObject(_ obj: SQLServerObjectIdentifier) {
        if selectedObjectIDs.contains(obj) {
            selectedObjectIDs.remove(obj)
        } else {
            selectedObjectIDs.insert(obj)
        }
    }

    func selectAll() {
        for group in objectsByCategory {
            for obj in group.objects { selectedObjectIDs.insert(obj) }
        }
    }

    func deselectAll() {
        selectedObjectIDs.removeAll()
    }

    // MARK: - Load Objects

    func loadObjects() {
        guard let deps = session.dependencies else { return }
        isLoadingObjects = true
        let db = databaseName

        Task { [deps, db] in
            do {
                let objects = try await deps.listAllObjects(database: db)
                let grouped = Dictionary(grouping: objects) { $0.typeCategory }
                let categoryOrder = ["Tables", "Views", "Stored Procedures", "Functions", "Triggers", "Synonyms", "Types", "Sequences"]
                self.objectsByCategory = categoryOrder.compactMap { cat in
                    guard let objs = grouped[cat], !objs.isEmpty else { return nil }
                    return (category: cat, objects: objs)
                }
                // Default: select all
                self.selectedObjectIDs = Set(objects)
                self.isLoadingObjects = false
            } catch {
                logger.error("Failed to load objects: \(error)")
                self.isLoadingObjects = false
            }
        }
    }

    // MARK: - Script Generation

    func generate() {
        guard let deps = session.dependencies else { return }
        isGenerating = true
        progress = 0
        statusMessage = "Analyzing dependencies..."
        generationError = nil
        generationSucceeded = false
        let db = databaseName

        Task { [deps, db] in
            do {
                let graph = try await deps.buildGraph(database: db)
                let allSorted = graph.resolvedOrder()
                let sortedSelected = allSorted.filter { selectedObjectIDs.contains($0) }

                var script = "-- Generated by Echo on \(Date().formatted())\n"
                if includeUseDatabase {
                    script += "USE [\(databaseName)];\nGO\n\n"
                }

                let total = Double(sortedSelected.count)
                for (index, obj) in sortedSelected.enumerated() {
                    statusMessage = "Scripting \(obj.qualifiedName)..."

                    if scriptDropAndCreate {
                        if checkExistence {
                            script += "IF OBJECT_ID(N'\(obj.qualifiedName)', N'\(obj.type)') IS NOT NULL\n"
                            script += "    DROP \(Self.sqlKeyword(for: obj.type)) \(obj.qualifiedName);\nGO\n\n"
                        } else {
                            script += "DROP \(Self.sqlKeyword(for: obj.type)) \(obj.qualifiedName);\nGO\n\n"
                        }
                    }

                    if let definition = try await deps.scriptObjectDDL(
                        database: db,
                        schema: obj.schema,
                        name: obj.name,
                        objectType: obj.type
                    ) {
                        if checkExistence && !scriptDropAndCreate {
                            script += "IF OBJECT_ID(N'\(obj.qualifiedName)', N'\(obj.type)') IS NULL\nBEGIN\n"
                            script += definition
                            script += "\nEND\nGO\n\n"
                        } else {
                            script += definition
                            script += "\nGO\n\n"
                        }
                    }

                    progress = Double(index + 1) / max(total, 1)
                }

                self.generatedScript = script
                self.statusMessage = "Script generation complete."
                self.isGenerating = false
                self.generationSucceeded = true
                deliverOutput(script)
            } catch {
                logger.error("Script generation failed: \(error)")
                self.generationError = error.localizedDescription
                self.statusMessage = "Error: \(error.localizedDescription)"
                self.isGenerating = false
            }
        }
    }

    // MARK: - Output Delivery

    private func deliverOutput(_ script: String) {
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

    // MARK: - Helpers

    private static func sqlKeyword(for type: String) -> String {
        switch type {
        case "U": return "TABLE"
        case "V": return "VIEW"
        case "P": return "PROCEDURE"
        case "FN", "IF", "TF": return "FUNCTION"
        case "TR": return "TRIGGER"
        case "SN": return "SYNONYM"
        case "TT": return "TYPE"
        case "SO": return "SEQUENCE"
        default: return "OBJECT"
        }
    }
}
