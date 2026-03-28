import Foundation
import MySQLKit

extension MySQLDatabaseSecurityViewModel {
    enum AdvancedObjectSection: String, CaseIterable {
        case functions = "Functions"
        case procedures = "Procedures"
        case triggers = "Triggers"
        case events = "Events"
    }

    struct AdvancedObjectDefinition: Identifiable, Hashable {
        enum Kind: String {
            case function
            case procedure
            case trigger
            case event
        }

        let kind: Kind
        let schema: String
        let name: String
        let definition: String

        var id: String { "\(kind.rawValue):\(schema).\(name)" }
    }

    var filteredFunctions: [MySQLRoutineInfo] {
        routines.filter { $0.type.caseInsensitiveCompare("FUNCTION") == .orderedSame }
    }

    var filteredProcedures: [MySQLRoutineInfo] {
        routines.filter { $0.type.caseInsensitiveCompare("PROCEDURE") == .orderedSame }
    }

    var selectedRoutine: MySQLRoutineInfo? {
        routines.first { selectedRoutineID.contains($0.id) }
    }

    var selectedTrigger: MySQLTriggerInfo? {
        triggers.first { selectedTriggerID.contains($0.id) }
    }

    var selectedEvent: MySQLEventInfo? {
        events.first { selectedEventID.contains($0.id) }
    }

    func loadProgrammableObjects(mysql: MySQLSession) async {
        isLoadingAdvancedObjects = true
        defer { isLoadingAdvancedObjects = false }

        do {
            if availableObjectSchemas.isEmpty {
                availableObjectSchemas = try await mysql.listDatabases().sorted()
                if advancedObjectSchemaFilter.isEmpty {
                    advancedObjectSchemaFilter = try await mysql.currentDatabaseName() ?? availableObjectSchemas.first ?? ""
                }
            }

            let schemaName = advancedObjectSchemaFilter
            guard !schemaName.isEmpty else { return }

            async let routinesResult = mysql.client.metadata.listRoutines(in: schemaName)
            async let triggersResult = mysql.client.metadata.listTriggers(in: schemaName)
            async let eventsResult = mysql.client.metadata.listEvents(in: schemaName)

            routines = try await routinesResult
            triggers = try await triggersResult
            events = try await eventsResult

            switch selectedAdvancedObjectSection {
            case .functions:
                if selectedRoutine == nil {
                    selectedRoutineID = filteredFunctions.first.map { [$0.id] } ?? []
                }
            case .procedures:
                if selectedRoutine == nil || selectedRoutine?.type.caseInsensitiveCompare("PROCEDURE") != .orderedSame {
                    selectedRoutineID = filteredProcedures.first.map { [$0.id] } ?? []
                }
            case .triggers:
                if selectedTrigger == nil {
                    selectedTriggerID = triggers.first.map { [$0.id] } ?? []
                }
            case .events:
                if selectedEvent == nil {
                    selectedEventID = events.first.map { [$0.id] } ?? []
                }
            }

            await loadSelectedAdvancedObjectDefinition()
        } catch {
            panelState?.appendMessage("Failed to load MySQL advanced objects: \(error.localizedDescription)", severity: .error)
        }
    }

    func loadSelectedAdvancedObjectDefinition() async {
        guard
            let mysql = session as? MySQLSession,
            !advancedObjectSchemaFilter.isEmpty
        else {
            selectedAdvancedObjectDefinition = nil
            return
        }

        do {
            switch selectedAdvancedObjectSection {
            case .functions:
                guard let routine = filteredFunctions.first(where: { selectedRoutineID.contains($0.id) }) else {
                    selectedAdvancedObjectDefinition = nil
                    return
                }
                let definition = try await mysql.client.metadata.objectDefinition(named: routine.name, schema: advancedObjectSchemaFilter, kind: .function)
                selectedAdvancedObjectDefinition = AdvancedObjectDefinition(kind: .function, schema: routine.schema, name: routine.name, definition: definition)
            case .procedures:
                guard let routine = filteredProcedures.first(where: { selectedRoutineID.contains($0.id) }) else {
                    selectedAdvancedObjectDefinition = nil
                    return
                }
                let definition = try await mysql.client.metadata.objectDefinition(named: routine.name, schema: advancedObjectSchemaFilter, kind: .procedure)
                selectedAdvancedObjectDefinition = AdvancedObjectDefinition(kind: .procedure, schema: routine.schema, name: routine.name, definition: definition)
            case .triggers:
                guard let trigger = selectedTrigger else {
                    selectedAdvancedObjectDefinition = nil
                    return
                }
                let definition = try await mysql.client.metadata.objectDefinition(named: trigger.name, schema: advancedObjectSchemaFilter, kind: .trigger)
                selectedAdvancedObjectDefinition = AdvancedObjectDefinition(kind: .trigger, schema: trigger.schema, name: trigger.name, definition: definition)
            case .events:
                guard let event = selectedEvent else {
                    selectedAdvancedObjectDefinition = nil
                    return
                }
                let definition = try await mysql.client.metadata.objectDefinition(named: event.name, schema: advancedObjectSchemaFilter, kind: .event)
                selectedAdvancedObjectDefinition = AdvancedObjectDefinition(kind: .event, schema: event.schema, name: event.name, definition: definition)
            }
        } catch {
            panelState?.appendMessage("Failed to load object definition: \(error.localizedDescription)", severity: .error)
            selectedAdvancedObjectDefinition = nil
        }
    }
}
