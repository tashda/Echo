#if os(macOS)
import AppKit
import EchoSense

extension SQLTextView {
    func currentCompletionQuery() -> SQLAutoCompletionQuery? {
        makeCompletionQuery()
    }

    func currentSQLDialect() -> SQLDialect {
        let type = completionContext?.databaseType ?? .postgresql
        switch type {
        case .postgresql: return .postgresql
        case .mysql: return .mysql
        case .microsoftSQL: return .microsoftSQL
        case .sqlite: return .sqlite
        }
    }

    func makeCompletionQuery() -> SQLAutoCompletionQuery? {
        guard textStorage != nil else { return nil }
        let selection = selectedRange()
        guard selection.location != NSNotFound, selection.length == 0 else { return nil }

        let nsString = string as NSString
        let tokenRange = tokenRange(at: selection.location, in: nsString)
        let token: String
        if tokenRange.length > 0 {
            token = nsString.substring(with: tokenRange)
        } else {
            token = ""
        }

        let rawComponents = token.split(separator: ".", omittingEmptySubsequences: false).map { String($0) }
        let normalizedComponents = rawComponents.map { component -> String in
            component.trimmingCharacters(in: SQLTextView.identifierDelimiterCharacterSet)
        }
        let prefix = normalizedComponents.last ?? ""
        let pathComponents = normalizedComponents.dropLast().filter { !$0.isEmpty }

        let replacementRange = replacementRange(for: prefix, tokenRange: tokenRange, caretLocation: selection.location)
        let precedingKeyword = previousKeyword(before: tokenRange.location, in: nsString)
        let precedingCharacter = previousNonWhitespaceCharacter(before: tokenRange.location, in: nsString)
        let focusTable = inferFocusTable(before: selection.location, in: nsString)
        var scopeTables = self.tablesInScope(before: selection.location, in: nsString)
        if let focus = focusTable, !scopeTables.contains(where: { $0.matches(schema: focus.schema, name: focus.name) }) {
            scopeTables.append(focus)
        }

        let trailingTables = self.tablesInScope(after: selection.location, in: nsString)
        for table in trailingTables where !scopeTables.contains(where: { $0.isEquivalent(to: table) }) {
            scopeTables.append(table)
        }

        let catalog = SQLDatabaseCatalog(schemas: [])
        let parsedContext = SQLContextParser(text: string,
                                             caretLocation: selection.location,
                                             dialect: currentSQLDialect(),
                                             catalog: catalog).parse()

        return SQLAutoCompletionQuery(
            token: token,
            prefix: prefix,
            pathComponents: Array(pathComponents),
            replacementRange: replacementRange,
            precedingKeyword: precedingKeyword,
            precedingCharacter: precedingCharacter,
            focusTable: focusTable,
            tablesInScope: scopeTables,
            clause: parsedContext.clause
        )
    }

    func enrichedQuery(_ query: SQLAutoCompletionQuery,
                       with metadata: SQLCompletionMetadata) -> SQLAutoCompletionQuery {
        let metadataTables = metadata.tablesInScope.map { reference in
            SQLAutoCompletionTableFocus(schema: reference.schema,
                                        name: reference.name,
                                        alias: reference.alias)
        }

        var mergedTables = query.tablesInScope
        if !metadataTables.isEmpty {
            for candidate in metadataTables where !mergedTables.contains(where: { $0.isEquivalent(to: candidate) }) {
                mergedTables.append(candidate)
            }
        }

        let metadataFocus = metadata.focusTable.map {
            SQLAutoCompletionTableFocus(schema: $0.schema,
                                        name: $0.name,
                                        alias: $0.alias)
        }

        let resolvedClause: SQLClause = metadata.clause == .unknown ? query.clause : metadata.clause
        let resolvedKeyword = metadata.precedingKeyword ?? query.precedingKeyword
        let resolvedPathComponents = metadata.pathComponents.isEmpty ? query.pathComponents : metadata.pathComponents

        return SQLAutoCompletionQuery(
            token: query.token,
            prefix: query.prefix,
            pathComponents: resolvedPathComponents,
            replacementRange: query.replacementRange,
            precedingKeyword: resolvedKeyword,
            precedingCharacter: query.precedingCharacter,
            focusTable: metadataFocus ?? query.focusTable,
            tablesInScope: mergedTables,
            clause: resolvedClause
        )
    }

    private func replacementRange(for prefix: String, tokenRange: NSRange, caretLocation: Int) -> NSRange {
        let prefixLength = (prefix as NSString).length
        let start = max(tokenRange.location, tokenRange.location + tokenRange.length - prefixLength)
        let length = max(0, caretLocation - start)
        return NSRange(location: start, length: length)
    }

    func tokenRange(at caretLocation: Int, in string: NSString) -> NSRange {
        var start = caretLocation
        while start > 0 && isCompletionCharacter(string.character(at: start - 1)) {
            start -= 1
        }

        var end = caretLocation
        let length = string.length
        while end < length && isCompletionCharacter(string.character(at: end)) {
            end += 1
        }

        return NSRange(location: start, length: end - start)
    }

    func isCompletionCharacter(_ char: unichar) -> Bool {
        guard let scalar = UnicodeScalar(char) else { return false }
        return SQLTextView.completionTokenCharacterSet.contains(scalar)
    }

    private func previousKeyword(before location: Int, in string: NSString) -> String? {
        guard location > 0 else { return nil }
        let prefixRange = NSRange(location: 0, length: location)
        let substring = string.substring(with: prefixRange)
        let trimmed = substring.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let components = trimmed.components(separatedBy: CharacterSet.alphanumerics.inverted)
        guard let keyword = components.last(where: { !$0.isEmpty }) else { return nil }
        return keyword.lowercased()
    }

    private func previousNonWhitespaceCharacter(before location: Int, in string: NSString) -> Character? {
        var index = location - 1
        while index >= 0 {
            let scalarValue = string.character(at: index)
            guard let scalar = UnicodeScalar(scalarValue) else { break }
            if !CharacterSet.whitespacesAndNewlines.contains(scalar) {
                return Character(scalar)
            }
            index -= 1
        }
        return nil
    }

    private func inferFocusTable(before location: Int, in string: NSString) -> SQLAutoCompletionTableFocus? {
        guard location > 0 else { return nil }
        let prefixRange = NSRange(location: 0, length: location)
        let substring = string.substring(with: prefixRange)
        guard !substring.isEmpty else { return nil }

        return extractTables(from: substring).last
    }

}
#endif
