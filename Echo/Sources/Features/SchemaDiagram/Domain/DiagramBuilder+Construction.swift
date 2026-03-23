import Foundation
import SwiftUI
import OSLog

extension DiagramBuilder {
    func buildSchemaDiagram(
        for object: SchemaObjectInfo,
        session: any DiagramSchemaProvider,
        projectID: UUID,
        cacheKey: DiagramCacheKey?,
        progress: (@Sendable (String) -> Void)? = nil,
        isPrefetch: Bool = false
    ) async throws -> SchemaDiagramViewModel {
        let baseKey = DiagramTableKey(schema: object.schema, name: object.name)
        progress?("Loading \(baseKey.schema).\(baseKey.name)…")
        
        let baseDetails = try await session.getTableStructureDetails(
            schema: object.schema,
            table: object.name
        )

        var tableDetails: [DiagramTableKey: TableStructureDetails] = [baseKey: baseDetails]
        var relatedKeys = Set<DiagramTableKey>()
        var inboundRelationshipKeys = Set<DiagramTableKey>()
        var outboundRelationshipKeys = Set<DiagramTableKey>()

        var dependencyPlaceholders: [DiagramTableKey: PlaceholderAccumulator] = [:]
        var referencedColumnPlaceholders: [DiagramTableKey: PlaceholderAccumulator] = [:]

        for fk in baseDetails.foreignKeys {
            let referencedSchema = fk.referencedSchema.isEmpty ? baseKey.schema : fk.referencedSchema
            let key = DiagramTableKey(schema: referencedSchema, name: fk.referencedTable)
            relatedKeys.insert(key)
            outboundRelationshipKeys.insert(key)

            var accumulator = referencedColumnPlaceholders[key] ?? PlaceholderAccumulator()
            accumulator.addColumns(fk.referencedColumns)
            referencedColumnPlaceholders[key] = accumulator
        }

        for dependency in baseDetails.dependencies {
            let key = normalize(dependency.referencedTable, fallbackSchema: object.schema)
            relatedKeys.insert(key)
            inboundRelationshipKeys.insert(key)

            guard key != baseKey else { continue }

            var accumulator = dependencyPlaceholders[key] ?? PlaceholderAccumulator()
            accumulator.addColumns(dependency.baseColumns)

            let foreignKey = TableStructureDetails.ForeignKey(
                name: dependency.name,
                columns: dependency.baseColumns,
                referencedSchema: baseKey.schema,
                referencedTable: baseKey.name,
                referencedColumns: dependency.referencedColumns,
                onUpdate: dependency.onUpdate,
                onDelete: dependency.onDelete
            )
            accumulator.addForeignKey(foreignKey)
            dependencyPlaceholders[key] = accumulator
        }

        relatedKeys.remove(baseKey)

        if !relatedKeys.isEmpty {
            progress?("Loading related tables…")
            for key in relatedKeys where tableDetails[key] == nil {
                do {
                    progress?("Fetching \(key.schema).\(key.name)…")
                    let details = try await session.getTableStructureDetails(
                        schema: key.schema,
                        table: key.name
                    )
                    tableDetails[key] = details
                } catch {
                    Logger.diagram.debug("Failed to fetch diagram details for \(key.schema).\(key.name): \(String(reflecting: error))")
                }
            }

            for key in relatedKeys where tableDetails[key] == nil {
                if var accumulator = dependencyPlaceholders[key] {
                    if let referenced = referencedColumnPlaceholders[key] {
                        accumulator.addColumns(referenced.columns)
                    }
                    let columns = accumulator.columns.map {
                        TableStructureDetails.Column(
                            name: $0,
                            dataType: "unknown",
                            isNullable: true,
                            defaultValue: nil,
                            generatedExpression: nil
                        )
                    }
                    let details = TableStructureDetails(
                        columns: columns,
                        primaryKey: nil,
                        indexes: [],
                        uniqueConstraints: [],
                        foreignKeys: accumulator.foreignKeys,
                        dependencies: []
                    )
                    tableDetails[key] = details
                } else if let referenced = referencedColumnPlaceholders[key] {
                    let columns = referenced.columns.map {
                        TableStructureDetails.Column(
                            name: $0,
                            dataType: "unknown",
                            isNullable: true,
                            defaultValue: nil,
                            generatedExpression: nil
                        )
                    }
                    let details = TableStructureDetails(
                        columns: columns,
                        primaryKey: nil,
                        indexes: [],
                        uniqueConstraints: [],
                        foreignKeys: [],
                        dependencies: []
                    )
                    tableDetails[key] = details
                }
            }
        }

        progress?("Finalizing diagram…")
        let title = "\(object.schema).\(object.name)"
        let baseStructure = tableDetails[baseKey]
        let relatedEntries = tableDetails
            .filter { $0.key != baseKey }
            .map { DiagramStructureSnapshot.TableEntry(schema: $0.key.schema, name: $0.key.name, details: $0.value) }
        
        let structureSnapshot: DiagramStructureSnapshot? = baseStructure.map { details in
            DiagramStructureSnapshot(
                baseTable: .init(schema: baseKey.schema, name: baseKey.name, details: details),
                relatedTables: relatedEntries
            )
        }
        let checksum = baseStructure.map { DiagramChecksum.makeChecksum(base: $0, related: relatedEntries) }

        let viewModel = makeDiagramViewModel(
            title: title,
            baseKey: baseKey,
            tableDetails: tableDetails,
            layoutSnapshot: nil,
            structureSnapshot: structureSnapshot,
            checksum: checksum,
            loadSource: .live(Date()),
            inboundKeys: inboundRelationshipKeys,
            outboundKeys: outboundRelationshipKeys
        )

        if let cacheKey, let structureSnapshot, let checksum {
            let layout = viewModel.layoutSnapshot()
            let payload = DiagramCachePayload(
                key: cacheKey,
                checksum: checksum,
                structure: structureSnapshot,
                layout: layout,
                loadingSummary: nil
            )
            Task {
                try? await cacheManager.stashPayload(payload)
            }
        }

        if !isPrefetch {
            await scheduleRelatedPrefetch(
                session: session,
                baseKey: baseKey,
                relatedKeys: Array(relatedKeys),
                projectID: projectID
            )
        }

        return viewModel
    }

    func hydrateCachedDiagram(from payload: DiagramCachePayload) -> SchemaDiagramViewModel {
        let baseKey = DiagramTableKey(schema: payload.key.schema, name: payload.key.table)
        var tableDetails: [DiagramTableKey: TableStructureDetails] = [:]
        tableDetails[baseKey] = payload.structure.baseTable.details
        for entry in payload.structure.relatedTables {
            let key = DiagramTableKey(schema: entry.schema, name: entry.name)
            tableDetails[key] = entry.details
        }

        var outboundKeys: Set<DiagramTableKey> = []
        var inboundKeys: Set<DiagramTableKey> = []

        if let baseDetails = tableDetails[baseKey] {
            for fk in baseDetails.foreignKeys {
                let schema = fk.referencedSchema.isEmpty ? baseKey.schema : fk.referencedSchema
                outboundKeys.insert(DiagramTableKey(schema: schema, name: fk.referencedTable))
            }
        }

        for entry in payload.structure.relatedTables {
            let key = DiagramTableKey(schema: entry.schema, name: entry.name)
            let referencesBase = entry.details.foreignKeys.contains { fk in
                let referencedSchema = fk.referencedSchema.isEmpty ? entry.schema : fk.referencedSchema
                return referencedSchema.caseInsensitiveCompare(baseKey.schema) == .orderedSame
                    && fk.referencedTable.caseInsensitiveCompare(baseKey.name) == .orderedSame
            }
            if referencesBase {
                inboundKeys.insert(key)
            }
        }

        let title = "\(payload.key.schema).\(payload.key.table)"
        return makeDiagramViewModel(
            title: title,
            baseKey: baseKey,
            tableDetails: tableDetails,
            layoutSnapshot: payload.layout,
            structureSnapshot: payload.structure,
            checksum: payload.checksum,
            loadSource: .cache(payload.generatedAt),
            inboundKeys: inboundKeys,
            outboundKeys: outboundKeys
        )
    }
}
