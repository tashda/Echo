import Foundation

struct JoinSuggestionProvider: SQLSuggestionProvider {
    func suggestions(in context: SQLProviderContext) -> [SQLCompletionSuggestion] {
        switch context.sqlContext.clause {
        case .joinCondition:
            return joinConditionSuggestions(in: context)
        case .joinTarget:
            return joinTargetSuggestions(in: context)
        default:
            return []
        }
    }

    private func joinConditionSuggestions(in context: SQLProviderContext) -> [SQLCompletionSuggestion] {
        let references = context.sqlContext.tablesInScope
        guard references.count >= 2 else { return [] }

        let identifierToken = context.identifier.trimmedToken.lowercased()
        var resolved: [(ref: SQLContext.TableReference, res: SQLTableResolution?)] = []
        resolved.reserveCapacity(references.count)
        for ref in references {
            resolved.append((ref, context.resolve(ref)))
        }

        var results: [SQLCompletionSuggestion] = []
        var seen = Set<String>()

        for (sourceRef, sourceResolution) in resolved {
            guard let sourceResolution else { continue }
            for fk in sourceResolution.object.foreignKeys {
                for target in resolved {
                    guard let targetRes = target.res else { continue }
                    if target.ref.isEquivalent(to: sourceRef) { continue }
                    guard Self.matches(foreignKey: fk, target: targetRes) else { continue }

                    let expression = Self.joinExpression(source: sourceRef,
                                                         target: target.ref,
                                                         foreignKey: fk,
                                                         context: context)
                    guard !expression.isEmpty else { continue }

                    if !identifierToken.isEmpty && !expression.lowercased().hasPrefix(identifierToken) {
                        continue
                    }

                    let id = "join|\(sourceResolution.schema.name.lowercased())|\(sourceResolution.object.name.lowercased())|\(fk.columns.joined(separator: ","))|\(target.ref.alias?.lowercased() ?? target.ref.name.lowercased())"
                    guard seen.insert(id).inserted else { continue }

                    let detail = fk.name.map { "FK \($0)" } ?? "\(sourceResolution.schema.name).\(sourceResolution.object.name)"
                    let snippet = Self.appendSnippetPlaceholder(to: expression)

                    results.append(SQLCompletionSuggestion(id: id,
                                                           title: expression,
                                                           subtitle: "Join Condition",
                                                           detail: detail,
                                                           insertText: snippet,
                                                           kind: .join,
                                                           priority: 1700))
                }
            }
        }

        return results
    }

    private func joinTargetSuggestions(in context: SQLProviderContext) -> [SQLCompletionSuggestion] {
        let references = context.sqlContext.tablesInScope
        guard !references.isEmpty else { return [] }

        var resolved: [(ref: SQLContext.TableReference, res: SQLTableResolution?)] = []
        resolved.reserveCapacity(references.count)
        for ref in references {
            resolved.append((ref, context.resolve(ref)))
        }

        let existingKeys: Set<ObjectKey> = Set(resolved.compactMap { pair in
            guard let resolution = pair.res else { return nil }
            return ObjectKey(schema: resolution.schema.name.lowercased(),
                             name: resolution.object.name.lowercased())
        })
        let existingAliases: Set<String> = Set(resolved.map { ($0.ref.alias ?? $0.ref.name).lowercased() })
        let inboundIndex = Self.buildInboundIndex(catalog: context.catalog)

        var results: [SQLCompletionSuggestion] = []
        var seen = Set<String>()
        let identifier = context.identifier
        let prefix = identifier.lowercasePrefix

        for (sourceRef, maybeResolution) in resolved {
            guard let sourceResolution = maybeResolution else { continue }

            // Outgoing FK suggestions (source → target)
            for fk in sourceResolution.object.foreignKeys {
                guard let targetResolution = Self.resolveTarget(for: fk,
                                                                sourceSchema: sourceResolution.schema,
                                                                catalog: context.catalog) else { continue }

                let targetKey = ObjectKey(schema: targetResolution.schema.name.lowercased(),
                                          name: targetResolution.object.name.lowercased())
                if existingKeys.contains(targetKey) { continue }

                let alias = Self.makeAlias(for: targetResolution.object.name,
                                           existing: existingAliases)
                let targetRef = SQLContext.TableReference(schema: targetResolution.schema.name,
                                                          name: targetResolution.object.name,
                                                          alias: alias,
                                                          matchLocation: sourceRef.matchLocation)
                let expression = Self.joinExpression(source: sourceRef,
                                                     target: targetRef,
                                                     foreignKey: fk,
                                                     context: context)
                guard !expression.isEmpty else { continue }

                let (identifierText, displayName) = Self.joinTargetIdentifier(for: targetResolution,
                                                                              identifier: identifier,
                                                                              defaultSchemaLower: context.defaultSchemaLowercased,
                                                                              context: context)

                if !prefix.isEmpty &&
                    !identifierText.lowercased().hasPrefix(prefix) &&
                    !displayName.lowercased().hasPrefix(prefix) &&
                    !(alias?.lowercased().hasPrefix(prefix) ?? false) {
                    continue
                }

                let coreInsert = "\(identifierText)\(alias.map { " \($0)" } ?? "") ON \(expression)"
                let snippet = Self.appendSnippetPlaceholder(to: coreInsert)
                let id = "join-target|out|\(sourceResolution.schema.name.lowercased())|\(sourceResolution.object.name.lowercased())|\(fk.columns.joined(separator: ","))|\(targetResolution.schema.name.lowercased())|\(targetResolution.object.name.lowercased())"
                guard seen.insert(id).inserted else { continue }

                let subtitle = alias.map { "\($0) • Join helper" } ?? "Join helper"
                let detail = fk.name.map { "FK \($0)" } ?? "\(sourceResolution.object.name) → \(targetResolution.object.name)"

                results.append(SQLCompletionSuggestion(id: id,
                                                       title: displayName,
                                                       subtitle: subtitle,
                                                       detail: detail,
                                                       insertText: snippet,
                                                       kind: .join,
                                                       priority: 1680))
            }

            // Inbound FK suggestions (other → source)
            let sourceKey = ObjectKey(schema: sourceResolution.schema.name.lowercased(),
                                      name: sourceResolution.object.name.lowercased())
            if let inboundEntries = inboundIndex[sourceKey] {
                for entry in inboundEntries {
                    let targetResolution = SQLTableResolution(schema: entry.schema, object: entry.object)
                    let targetKey = ObjectKey(schema: targetResolution.schema.name.lowercased(),
                                              name: targetResolution.object.name.lowercased())
                    if existingKeys.contains(targetKey) { continue }

                    let alias = Self.makeAlias(for: targetResolution.object.name,
                                               existing: existingAliases)
                    let targetRef = SQLContext.TableReference(schema: targetResolution.schema.name,
                                                              name: targetResolution.object.name,
                                                              alias: alias,
                                                              matchLocation: sourceRef.matchLocation)
                    let expression = Self.joinExpression(source: targetRef,
                                                         target: sourceRef,
                                                         foreignKey: entry.foreignKey,
                                                         context: context)
                    guard !expression.isEmpty else { continue }

                    let (identifierText, displayName) = Self.joinTargetIdentifier(for: targetResolution,
                                                                                  identifier: identifier,
                                                                                  defaultSchemaLower: context.defaultSchemaLowercased,
                                                                                  context: context)

                    if !prefix.isEmpty &&
                        !identifierText.lowercased().hasPrefix(prefix) &&
                        !displayName.lowercased().hasPrefix(prefix) &&
                        !(alias?.lowercased().hasPrefix(prefix) ?? false) {
                        continue
                    }

                    let coreInsert = "\(identifierText)\(alias.map { " \($0)" } ?? "") ON \(expression)"
                    let snippet = Self.appendSnippetPlaceholder(to: coreInsert)
                    let id = "join-target|in|\(targetResolution.schema.name.lowercased())|\(targetResolution.object.name.lowercased())|\(entry.foreignKey.columns.joined(separator: ","))|\(sourceResolution.schema.name.lowercased())|\(sourceResolution.object.name.lowercased())"
                    guard seen.insert(id).inserted else { continue }

                    let subtitle = alias.map { "\($0) • Join helper" } ?? "Join helper"
                    let detail = entry.foreignKey.name.map { "FK \($0)" } ?? "\(targetResolution.object.name) → \(sourceResolution.object.name)"

                    results.append(SQLCompletionSuggestion(id: id,
                                                           title: displayName,
                                                           subtitle: subtitle,
                                                           detail: detail,
                                                           insertText: snippet,
                                                           kind: .join,
                                                           priority: 1675))
                }
            }
        }

        return results
    }

    private static func appendSnippetPlaceholder(to text: String) -> String {
        if text.contains("<#") {
            return text
        }
        return text + "<# #>"
    }

    private static func matches(foreignKey: SQLForeignKey,
                                target: SQLTableResolution) -> Bool {
        let referencedSchema = foreignKey.referencedSchema?.lowercased()
        let targetSchema = target.schema.name.lowercased()
        if let referencedSchema, referencedSchema != targetSchema {
            return false
        }
        return foreignKey.referencedTable.lowercased() == target.object.name.lowercased()
    }

    private static func joinExpression(source: SQLContext.TableReference,
                                       target: SQLContext.TableReference,
                                       foreignKey: SQLForeignKey,
                                       context: SQLProviderContext) -> String {
        guard foreignKey.columns.count == foreignKey.referencedColumns.count else { return "" }
        let leftQualifier = context.qualifier(for: source)
        let rightQualifier = context.qualifier(for: target)

        let pairs = zip(foreignKey.columns, foreignKey.referencedColumns)
        let segments = pairs.map { lhs, rhs in
            let leftColumn = context.quotedColumn(lhs)
            let rightColumn = context.quotedColumn(rhs)
            return "\(leftQualifier).\(leftColumn) = \(rightQualifier).\(rightColumn)"
        }
        return segments.joined(separator: " AND ")
    }

    private static func resolveTarget(for foreignKey: SQLForeignKey,
                                      sourceSchema: SQLSchema,
                                      catalog: SQLDatabaseCatalog) -> SQLTableResolution? {
        if let referencedSchema = foreignKey.referencedSchema?.lowercased() {
            if let schema = catalog.schemas.first(where: { $0.name.lowercased() == referencedSchema }),
               let object = schema.objects.first(where: { $0.name.caseInsensitiveCompare(foreignKey.referencedTable) == .orderedSame }) {
                return SQLTableResolution(schema: schema, object: object)
            }
        } else {
            if let object = sourceSchema.objects.first(where: { $0.name.caseInsensitiveCompare(foreignKey.referencedTable) == .orderedSame }) {
                return SQLTableResolution(schema: sourceSchema, object: object)
            }
            for schema in catalog.schemas {
                if let object = schema.objects.first(where: { $0.name.caseInsensitiveCompare(foreignKey.referencedTable) == .orderedSame }) {
                    return SQLTableResolution(schema: schema, object: object)
                }
            }
        }
        return nil
    }

    private static func joinTargetIdentifier(for resolution: SQLTableResolution,
                                             identifier: SQLIdentifierContext,
                                             defaultSchemaLower: String?,
                                             context: SQLProviderContext) -> (String, String) {
        var components = identifier.precedingSegments
        if components.isEmpty {
            if let defaultSchemaLower,
               resolution.schema.name.lowercased() == defaultSchemaLower {
                components = []
            } else {
                components = [resolution.schema.name]
            }
        } else if let lastIndex = components.indices.last {
            let typedSchema = components[lastIndex]
            if resolution.schema.name.lowercased().hasPrefix(typedSchema.lowercased()) {
                components[lastIndex] = resolution.schema.name
            }
        }
        components.append(resolution.object.name)

        let identifierText = context.qualify(components)
        let displayName = resolution.object.name
        return (identifierText, displayName)
    }

    private static func makeAlias(for name: String,
                                  existing: Set<String>) -> String? {
        guard var base = AliasGenerator.shortcut(for: name) else { return nil }
        base = base.lowercased()
        var candidate = base
        var suffix = 2
        while existing.contains(candidate) {
            candidate = base + "\(suffix)"
            suffix += 1
        }
        return candidate
    }

    private static func buildInboundIndex(catalog: SQLDatabaseCatalog) -> [ObjectKey: [InboundEntry]] {
        var index: [ObjectKey: [InboundEntry]] = [:]
        for schema in catalog.schemas {
            for object in schema.objects {
                guard !object.foreignKeys.isEmpty else { continue }
                for fk in object.foreignKeys {
                    let referencedSchemaLower = fk.referencedSchema?.lowercased() ?? schema.name.lowercased()
                    let key = ObjectKey(schema: referencedSchemaLower,
                                        name: fk.referencedTable.lowercased())
                    let entry = InboundEntry(schema: schema, object: object, foreignKey: fk)
                    index[key, default: []].append(entry)
                }
            }
        }
        return index
    }

    private struct ObjectKey: Hashable {
        let schema: String
        let name: String
    }

    private struct InboundEntry {
        let schema: SQLSchema
        let object: SQLObject
        let foreignKey: SQLForeignKey
    }
}
