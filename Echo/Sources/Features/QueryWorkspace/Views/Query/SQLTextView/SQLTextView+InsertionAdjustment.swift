#if os(macOS)
import AppKit
import EchoSense

extension SQLTextView {

    func snippetPlaceholderIndex(containing selection: NSRange) -> Int? {
        guard selection.location != NSNotFound else { return nil }
        for (index, placeholder) in activeSnippetPlaceholders.enumerated() {
            let placeholderRange = placeholder.range
            if selection.length == 0 {
                if NSLocationInRange(selection.location, placeholderRange) ||
                    selection.location == NSMaxRange(placeholderRange) {
                    return index
                }
            } else {
                let start = selection.location
                let end = NSMaxRange(selection)
                if start >= placeholderRange.location &&
                    end <= NSMaxRange(placeholderRange) {
                    return index
                }
            }
        }
        return nil
    }

    func adjustedInsertion(for suggestion: SQLAutoCompletionSuggestion,
                                   originalText: String,
                                   proposedInsertion: String) -> String {
        switch suggestion.kind {
        case .column, .table, .view, .materializedView:
            break
        default:
            return proposedInsertion
        }

        let prefixCount = proposedInsertion.prefix { $0.isWhitespace }.count
        let suffixCount = proposedInsertion.reversed().prefix { $0.isWhitespace }.count
        let prefixString = String(proposedInsertion.prefix(prefixCount))
        let suffixString = String(proposedInsertion.suffix(suffixCount))

        let coreStartIndex = proposedInsertion.index(proposedInsertion.startIndex, offsetBy: prefixCount)
        let coreEndIndex = proposedInsertion.index(proposedInsertion.endIndex, offsetBy: -suffixCount)
        guard coreStartIndex <= coreEndIndex else { return proposedInsertion }
        let core = String(proposedInsertion[coreStartIndex..<coreEndIndex])
        guard !core.isEmpty else { return proposedInsertion }

        let trimmedOriginal = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOriginal.isEmpty else { return proposedInsertion }

        let originalComponents = trimmedOriginal.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let proposedComponents = core.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard !originalComponents.isEmpty else { return proposedInsertion }

        let wrappedComponents: [String]
        if originalComponents.count == proposedComponents.count {
            wrappedComponents = zip(originalComponents, proposedComponents).map { wrapComponent($1, using: $0) }
        } else if originalComponents.count == 1, proposedComponents.count > 1 {
            // Original is a partial name (e.g. "sh"), proposed has schema prefix (e.g. "HumanResources.Shift").
            // Preserve the full proposed path — only wrap the matching (last) component with the original's quoting.
            var result = proposedComponents
            result[result.count - 1] = wrapComponent(result[result.count - 1], using: originalComponents[0])
            wrappedComponents = result
        } else if originalComponents.count == 1 {
            wrappedComponents = [wrapComponent(core, using: originalComponents[0])]
        } else {
            return proposedInsertion
        }

        let wrappedCore = wrappedComponents.joined(separator: ".")
        return prefixString + wrappedCore + suffixString
    }

    internal func wrapComponent(_ component: String, using originalComponent: String) -> String {
        let trimmedOriginal = originalComponent.trimmingCharacters(in: .whitespaces)
        guard let first = trimmedOriginal.first else { return component }

        let delimiterPairs: [Character: Character] = ["\"": "\"", "`": "`", "[": "]"]
        guard let closing = delimiterPairs[first], trimmedOriginal.last == closing else {
            return component
        }

        let trimmedComponent = component.trimmingCharacters(in: .whitespaces)
        if trimmedComponent.first == first && trimmedComponent.last == closing {
            return component
        }

        let inner = trimmedComponent.trimmingCharacters(in: CharacterSet(charactersIn: "\"`[]"))
        return "\(first)\(inner)\(closing)"
    }
}
#endif
