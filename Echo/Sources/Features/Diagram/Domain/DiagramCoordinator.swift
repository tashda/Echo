import Foundation
import Observation
import SwiftUI

struct DiagramTableKey: Hashable, Sendable {
    let schema: String
    let name: String
    
    var identifier: String {
        "\(schema).\(name)".lowercased()
    }
}

@Observable @MainActor
final class DiagramCoordinator: DiagramCoordinatorProtocol, @unchecked Sendable {
    private let cacheManager: DiagramCacheManager
    private let keyStore: DiagramEncryptionKeyStore
    let prefetchService = DiagramPrefetchService()
    private var refreshTask: Task<Void, Never>?
    
    var sessionProvider: (@MainActor @Sendable (UUID) -> (any DiagramSchemaProvider)?)?
    var globalSettingsProvider: (@MainActor @Sendable () -> GlobalSettings)?

    init(cacheManager: DiagramCacheManager, keyStore: DiagramEncryptionKeyStore) {
        self.cacheManager = cacheManager
        self.keyStore = keyStore
        
        Task {
            await prefetchService.setHandler { [weak self] request in
                await self?.handlePrefetchRequest(request) ?? false
            }
        }
    }

    func updateConfiguration(with settings: GlobalSettings) async {
        let rootDirectory = DiagramCacheManager.defaultRootDirectory()
        let normalizedLimit = max(settings.diagramCacheMaxBytes, 64 * 1_024 * 1_024)
        let configuration = DiagramCacheManager.Configuration(
            rootDirectory: rootDirectory,
            maximumBytes: UInt64(normalizedLimit)
        )
        await cacheManager.updateConfiguration(configuration)
    }

    func handleDiagramSettingsChange(_ settings: GlobalSettings) async {
        await prefetchService.cancelAll()
        await MainActor.run {
            restartDiagramRefreshTask(with: settings)
        }
    }

    private func restartDiagramRefreshTask(with settings: GlobalSettings) {
        refreshTask?.cancel()
        refreshTask = nil
        guard settings.diagramPrefetchMode == .full else { return }
        let cadence = settings.diagramRefreshCadence
        guard cadence != .never else { return }
        
        let intervalSeconds: TimeInterval = switch cadence {
            case .never: 0
            case .daily: 24 * 60 * 60
            case .weekly: 7 * 24 * 60 * 60
        }
        
        guard intervalSeconds > 0 else { return }
        let intervalNanoseconds = UInt64(intervalSeconds) * 1_000_000_000
        
        refreshTask = Task.detached(priority: .utility) {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: intervalNanoseconds)
                if Task.isCancelled { break }
            }
        }
    }

    func buildSchemaDiagram(for object: SchemaObjectInfo, projectID: UUID) async throws -> SchemaDiagramViewModel {
        throw NSError(domain: "DiagramCoordinator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Use buildSchemaDiagram(for:session:...)"])
    }

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

        struct PlaceholderAccumulator {
            var columns: [String] = []
            var columnSet: Set<String> = []
            var foreignKeys: [TableStructureDetails.ForeignKey] = []

            mutating func addColumn(_ name: String) {
                guard !name.isEmpty else { return }
                let key = name.lowercased()
                if columnSet.insert(key).inserted {
                    columns.append(name)
                }
            }

            mutating func addColumns(_ names: [String]) {
                for name in names {
                    addColumn(name)
                }
            }

            mutating func addForeignKey(_ foreignKey: TableStructureDetails.ForeignKey) {
                foreignKeys.append(foreignKey)
            }
        }

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
            let key = Self.normalize(dependency.referencedTable, fallbackSchema: object.schema)
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
                    #if DEBUG
                    print("Failed to fetch diagram details for \(key.schema).\(key.name): \(String(reflecting: error))")
                    #endif
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

    func queueDiagramPrefetch(for object: SchemaObjectInfo, relatedKeys: [DiagramTableKey], projectID: UUID) async {
    }

    @MainActor
    func handlePrefetchRequest(_ request: DiagramPrefetchService.Request) async -> Bool {
        let settings = globalSettingsProvider?() ?? GlobalSettings()
        guard settings.diagramPrefetchMode != .off else { return false }
        
        if let _ = try? await cacheManager.payload(for: request.cacheKey) {
            return true
        }
        
        guard let session = sessionProvider?(request.connectionSessionID) else {
            return false
        }
        
        do {
            _ = try await buildSchemaDiagram(
                for: request.object,
                session: session,
                projectID: request.cacheKey.projectID,
                cacheKey: request.cacheKey,
                progress: nil,
                isPrefetch: true
            )
            return true
        } catch {
            return false
        }
    }

    @MainActor
    func persistDiagramLayout(for viewModel: SchemaDiagramViewModel) async {
        guard let snapshot = viewModel.cachedStructure,
              let checksum = viewModel.cachedChecksum else { return }
        
        let cacheKey = DiagramCacheKey(
            projectID: UUID(), // Fallback, will need proper resolution
            connectionID: UUID(), // Fallback
            schema: viewModel.nodes.first?.schema ?? "",
            table: viewModel.nodes.first?.name ?? ""
        )
        
        let payload = DiagramCachePayload(
            key: cacheKey,
            checksum: checksum,
            structure: snapshot,
            layout: viewModel.layoutSnapshot(),
            loadingSummary: nil
        )
        
        try? await cacheManager.stashPayload(payload)
    }

    @MainActor
    func refreshDiagram(for viewModel: SchemaDiagramViewModel) async {
        // WorkspaceSessionStore bridge for now until DiagramCoordinator has everything
    }

    @MainActor
    func scheduleRelatedPrefetch(
        session: any DiagramSchemaProvider,
        baseKey: DiagramTableKey,
        relatedKeys: [DiagramTableKey],
        projectID: UUID
    ) async {
        let settings = globalSettingsProvider?() ?? GlobalSettings()
        guard settings.diagramPrefetchMode != .off else { return }
        
        let filteredKeys = relatedKeys.filter { $0 != baseKey }
        guard !filteredKeys.isEmpty else { return }
        
        let sortedKeys = filteredKeys.sorted {
            if $0.schema.caseInsensitiveCompare($1.schema) == .orderedSame {
                return $0.name.lowercased() < $1.name.lowercased()
            }
            return $0.schema.lowercased() < $1.schema.lowercased()
        }
        
        let keysToQueue: [DiagramTableKey] = switch settings.diagramPrefetchMode {
            case .off: []
            case .recentlyOpened: Array(sortedKeys.prefix(8))
            case .full: sortedKeys
        }
        
        for key in keysToQueue {
            let cacheKey = DiagramCacheKey(
                projectID: projectID,
                connectionID: session.connectionID,
                schema: key.schema,
                table: key.name
            )
            let object = SchemaObjectInfo(name: key.name, schema: key.schema, type: .table)
            let request = DiagramPrefetchService.Request(
                cacheKey: cacheKey,
                connectionSessionID: session.connectionID,
                object: object,
                isBackgroundSweep: false
            )
            await prefetchService.enqueue(request, prioritize: true)
        }
    }

    private static func normalize(_ identifier: String, fallbackSchema: String) -> DiagramTableKey {
        func clean(_ raw: String) -> String {
            var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            func stripWrapping(_ prefix: Character, _ suffix: Character) {
                if value.count >= 2, value.first == prefix, value.last == suffix {
                    value.removeFirst()
                    value.removeLast()
                }
            }
            let wrappers: [(Character, Character)] = [("\"", "\""), ("`", "`"), ("[", "]")]
            for (start, end) in wrappers where value.first == start && value.last == end {
                stripWrapping(start, end)
                break
            }
            value = value.replacingOccurrences(of: "\"\"", with: "\"")
            return value
        }

        func splitComponents(_ identifier: String) -> [String] {
            guard !identifier.isEmpty else { return [] }
            var components: [String] = []
            var current = ""
            var activeQuote: Character?
            var bracketDepth = 0
            var index = identifier.startIndex
            while index < identifier.endIndex {
                let char = identifier[index]
                switch char {
                case "\"":
                    current.append(char)
                    if activeQuote == "\"" {
                        let nextIndex = identifier.index(after: index)
                        if nextIndex < identifier.endIndex && identifier[nextIndex] == "\"" {
                            current.append(identifier[nextIndex])
                            index = nextIndex
                        } else { activeQuote = nil }
                    } else if activeQuote == nil { activeQuote = "\"" }
                case "`":
                    current.append(char)
                    if activeQuote == "`" { activeQuote = nil }
                    else if activeQuote == nil { activeQuote = "`" }
                case "[":
                    bracketDepth += 1
                    current.append(char)
                case "]":
                    if bracketDepth > 0 { bracketDepth -= 1 }
                    current.append(char)
                case "." where activeQuote == nil && bracketDepth == 0:
                    components.append(current)
                    current = ""
                default:
                    current.append(char)
                }
                index = identifier.startIndex
            }
            components.append(current)
            return components.filter { !$0.isEmpty }
        }

        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = splitComponents(trimmed)
        if components.count >= 2 {
            let schemaComponent = components[components.count - 2]
            let tableComponent = components[components.count - 1]
            return DiagramTableKey(schema: clean(schemaComponent), name: clean(tableComponent))
        } else if let single = components.first {
            return DiagramTableKey(schema: fallbackSchema, name: clean(single))
        } else {
            return DiagramTableKey(schema: fallbackSchema, name: clean(trimmed))
        }
    }

    private func makeDiagramViewModel(
        title: String,
        baseKey: DiagramTableKey,
        tableDetails: [DiagramTableKey: TableStructureDetails],
        layoutSnapshot: DiagramLayoutSnapshot?,
        structureSnapshot: DiagramStructureSnapshot? = nil,
        checksum: String? = nil,
        loadSource: DiagramLoadSource = .live(Date()),
        inboundKeys: Set<DiagramTableKey> = [],
        outboundKeys: Set<DiagramTableKey> = []
    ) -> SchemaDiagramViewModel {
        func buildColumns(for details: TableStructureDetails) -> [SchemaDiagramColumn] {
            let primaryKeys = Set(details.primaryKey?.columns.map { $0.lowercased() } ?? [])
            let foreignKeys = Set(details.foreignKeys.flatMap { $0.columns.map { $0.lowercased() } })
            return details.columns.map { column in
                SchemaDiagramColumn(
                    name: column.name,
                    dataType: column.dataType,
                    isPrimaryKey: primaryKeys.contains(column.name.lowercased()),
                    isForeignKey: foreignKeys.contains(column.name.lowercased())
                )
            }
        }

        var edges: [SchemaDiagramEdge] = []
        func appendForeignKeyEdges(from tableKey: DiagramTableKey, details: TableStructureDetails) {
            for fk in details.foreignKeys {
                let targetSchema = fk.referencedSchema.isEmpty ? tableKey.schema : fk.referencedSchema
                let targetKey = DiagramTableKey(schema: targetSchema, name: fk.referencedTable)
                for pair in zip(fk.columns, fk.referencedColumns) {
                    edges.append(
                        SchemaDiagramEdge(
                            fromNodeID: tableKey.identifier,
                            fromColumn: pair.0,
                            toNodeID: targetKey.identifier,
                            toColumn: pair.1,
                            relationshipName: fk.name
                        )
                    )
                }
            }
        }

        let spacingX: CGFloat = 420
        let spacingY: CGFloat = 320
        let baseIdentifier = baseKey.identifier
        let inboundIdentifiers = Set(inboundKeys.map(\.identifier))
        let outboundIdentifiers = Set(outboundKeys.map(\.identifier))
        let overlapIdentifiers = inboundIdentifiers.intersection(outboundIdentifiers)
        let inboundOnlyIdentifiers = inboundIdentifiers.subtracting(overlapIdentifiers)
        let outboundOnlyIdentifiers = outboundIdentifiers.subtracting(overlapIdentifiers)

        var storedPositions: [String: CGPoint] = layoutSnapshot?.nodePositions.reduce(into: [:]) { partial, entry in
            partial[entry.nodeID] = CGPoint(x: entry.x, y: entry.y)
        } ?? [:]

        let snapshotHasMeaningfulLayout: Bool = {
            guard let snapshot = layoutSnapshot, !snapshot.nodePositions.isEmpty else { return false }
            let uniqueKeys = Set(snapshot.nodePositions.map { node -> String in
                let xKey = Int((node.x * 1000).rounded(.toNearestOrEven))
                let yKey = Int((node.y * 1000).rounded(.toNearestOrEven))
                return "\(xKey)-\(yKey)"
            })
            return uniqueKeys.count > 1
        }()

        if !snapshotHasMeaningfulLayout { storedPositions.removeAll() }

        func rowsRequired(for count: Int, columns: Int) -> Int {
            guard count > 0 else { return 0 }
            return Int(ceil(Double(count) / Double(columns)))
        }

        func makeLeftPosition(index: inout Int, total: Int) -> CGPoint {
            let columns = max(1, min(3, total))
            let column = index % columns
            let row = index / columns
            index += 1
            return CGPoint(x: -CGFloat(column + 1) * spacingX, y: CGFloat(row) * spacingY)
        }

        func makeRightPosition(index: inout Int, total: Int) -> CGPoint {
            let columns = max(1, min(3, total))
            let column = index % columns
            let row = index / columns
            index += 1
            return CGPoint(x: CGFloat(column + 1) * spacingX, y: CGFloat(row) * spacingY)
        }

        func makeTopPosition(index: inout Int, total: Int) -> CGPoint {
            let columns = max(1, min(4, total))
            let column = index % columns
            let row = index / columns
            index += 1
            let centeredColumn = CGFloat(column) - CGFloat(columns - 1) / 2
            return CGPoint(x: centeredColumn * spacingX * 0.9, y: -CGFloat(row + 1) * spacingY)
        }

        func makeBottomPosition(index: inout Int, total: Int, verticalOffset: Int) -> CGPoint {
            let columns = max(2, min(4, total))
            let column = index % columns
            let row = index / columns
            index += 1
            let centeredColumn = CGFloat(column) - CGFloat(columns - 1) / 2
            return CGPoint(x: centeredColumn * spacingX * 0.9, y: CGFloat(verticalOffset + row + 1) * spacingY)
        }

        let sortedKeys = tableDetails.keys.sorted { lhs, rhs in
            if lhs.schema.caseInsensitiveCompare(rhs.schema) == .orderedSame {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.schema.localizedCaseInsensitiveCompare(rhs.schema) == .orderedAscending
        }

        let overlapKeys = sortedKeys.filter { overlapIdentifiers.contains($0.identifier) }
        let inboundKeysOrdered = sortedKeys.filter { inboundOnlyIdentifiers.contains($0.identifier) }
        let outboundKeysOrdered = sortedKeys.filter { outboundOnlyIdentifiers.contains($0.identifier) }
        let neutralKeys = sortedKeys.filter { $0 != baseKey && !inboundIdentifiers.contains($0.identifier) && !outboundIdentifiers.contains($0.identifier) }

        let inboundRows = rowsRequired(for: inboundKeysOrdered.count, columns: max(1, min(3, inboundKeysOrdered.count)))
        let outboundRows = rowsRequired(for: outboundKeysOrdered.count, columns: max(1, min(3, outboundKeysOrdered.count)))
        let verticalOffsetForBottom = max(inboundRows, outboundRows)

        var leftIndex = 0, rightIndex = 0, topIndex = 0, bottomIndex = 0
        if storedPositions[baseIdentifier] == nil { storedPositions[baseIdentifier] = .zero }
        if overlapKeys.contains(baseKey) { storedPositions[baseIdentifier] = .zero }

        for key in overlapKeys where key != baseKey && storedPositions[key.identifier] == nil {
            storedPositions[key.identifier] = makeTopPosition(index: &topIndex, total: overlapKeys.count)
        }
        for key in inboundKeysOrdered where storedPositions[key.identifier] == nil {
            storedPositions[key.identifier] = makeLeftPosition(index: &leftIndex, total: inboundKeysOrdered.count)
        }
        for key in outboundKeysOrdered where storedPositions[key.identifier] == nil {
            storedPositions[key.identifier] = makeRightPosition(index: &rightIndex, total: outboundKeysOrdered.count)
        }
        for key in neutralKeys where storedPositions[key.identifier] == nil {
            storedPositions[key.identifier] = makeBottomPosition(index: &bottomIndex, total: neutralKeys.count, verticalOffset: max(1, verticalOffsetForBottom))
        }

        var nodeModels: [SchemaDiagramNodeModel] = []
        if let baseDetails = tableDetails[baseKey] {
            nodeModels.append(SchemaDiagramNodeModel(schema: baseKey.schema, name: baseKey.name, columns: buildColumns(for: baseDetails), position: storedPositions[baseKey.identifier] ?? .zero))
        }
        for key in sortedKeys where key != baseKey {
            guard let details = tableDetails[key] else { continue }
            nodeModels.append(SchemaDiagramNodeModel(schema: key.schema, name: key.name, columns: buildColumns(for: details), position: storedPositions[key.identifier] ?? .zero))
        }

        if !snapshotHasMeaningfulLayout {
            let minimumSeparation: CGFloat = 320
            for _ in 0..<12 {
                var didAdjust = false
                for i in nodeModels.indices {
                    for j in nodeModels.indices where j > i {
                        let lhs = nodeModels[i], rhs = nodeModels[j]
                        if lhs.id == rhs.id { continue }
                        let vector = CGPoint(x: rhs.position.x - lhs.position.x, y: rhs.position.y - lhs.position.y)
                        let distance = max(0.001, hypot(vector.x, vector.y))
                        if distance < minimumSeparation {
                            let overlap = (minimumSeparation - distance) / 2
                            let angle = distance < 0.01 ? (Double(i + j).truncatingRemainder(dividingBy: 8) / 8.0) * 2 * .pi : atan2(vector.y, vector.x)
                            let adjustX = CGFloat(cos(angle)) * overlap, adjustY = CGFloat(sin(angle)) * overlap
                            if lhs.id == baseIdentifier { nodeModels[j].position = CGPoint(x: nodeModels[j].position.x + adjustX * 2, y: nodeModels[j].position.y + adjustY * 2) }
                            else if rhs.id == baseIdentifier { nodeModels[i].position = CGPoint(x: nodeModels[i].position.x - adjustX * 2, y: nodeModels[i].position.y - adjustY * 2) }
                            else {
                                nodeModels[i].position = CGPoint(x: nodeModels[i].position.x - adjustX, y: nodeModels[i].position.y - adjustY)
                                nodeModels[j].position = CGPoint(x: nodeModels[j].position.x + adjustX, y: nodeModels[j].position.y + adjustY)
                            }
                            didAdjust = true
                        }
                    }
                }
                if !didAdjust { break }
            }
        }

        for (key, details) in tableDetails { appendForeignKeyEdges(from: key, details: details) }

        return SchemaDiagramViewModel(
            nodes: nodeModels,
            edges: edges,
            baseNodeID: baseKey.identifier,
            title: title,
            layoutIdentifier: layoutSnapshot?.layoutID ?? "primary",
            cachedStructure: structureSnapshot,
            cachedChecksum: checksum,
            loadSource: loadSource
        )
    }
}

protocol DiagramSchemaProvider: Sendable {
    func getTableStructureDetails(schema: String, table: String) async throws -> TableStructureDetails
    var connectionID: UUID { get }
}
