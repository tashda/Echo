#if os(macOS)
import AppKit
import EchoSense

extension SQLTextView {
    func activateSnippetPlaceholders(_ ranges: [NSRange]) {
        let sorted = ranges.sorted { $0.location < $1.location }
        activeSnippetPlaceholders = sorted.map { SnippetPlaceholderPosition(range: $0) }
        if activeSnippetPlaceholders.isEmpty {
            currentSnippetPlaceholderIndex = -1
            return
        }
        currentSnippetPlaceholderIndex = 0
        isAdjustingSnippetSelection = true
        setSelectedRange(activeSnippetPlaceholders[0].range)
        isAdjustingSnippetSelection = false
    }

    func clearSnippetPlaceholders() {
        activeSnippetPlaceholders.removeAll()
        currentSnippetPlaceholderIndex = -1
    }

    private func selectSnippetPlaceholder(at index: Int) {
        guard index >= 0,
              index < activeSnippetPlaceholders.count else { return }
        currentSnippetPlaceholderIndex = index
        let range = activeSnippetPlaceholders[index].range
        isAdjustingSnippetSelection = true
        setSelectedRange(range)
        isAdjustingSnippetSelection = false
    }

    func adjustSnippetPlaceholders(forChange affectedRange: NSRange,
                                           replacementLength: Int) {
        guard !activeSnippetPlaceholders.isEmpty else { return }
        let delta = replacementLength - affectedRange.length
        if delta == 0 { return }

        for index in activeSnippetPlaceholders.indices {
            var placeholder = activeSnippetPlaceholders[index]
            let placeholderRange = placeholder.range

            if NSMaxRange(affectedRange) <= placeholderRange.location {
                placeholder.range.location = max(0, placeholderRange.location + delta)
            } else if NSIntersectionRange(placeholderRange, affectedRange).length > 0 ||
                        NSLocationInRange(affectedRange.location, placeholderRange) {
                let newLength = max(0, placeholderRange.length + delta)
                placeholder.range.length = newLength
                placeholder.range.location = min(placeholderRange.location, affectedRange.location)
            }

            activeSnippetPlaceholders[index] = placeholder
        }
    }

    func handleSnippetNavigation(_ event: NSEvent) -> Bool {
        guard !activeSnippetPlaceholders.isEmpty else { return false }

        if event.keyCode == 53 { // Escape
            clearSnippetPlaceholders()
            return true
        }

        guard let characters = event.charactersIgnoringModifiers,
              characters == "\t" else { return false }

        if currentSnippetPlaceholderIndex >= 0 &&
            currentSnippetPlaceholderIndex < activeSnippetPlaceholders.count {
            activeSnippetPlaceholders[currentSnippetPlaceholderIndex].range = selectedRange()
        }

        let isShiftHeld = event.modifierFlags.contains(.shift)

        if isShiftHeld {
            if currentSnippetPlaceholderIndex > 0 {
                selectSnippetPlaceholder(at: currentSnippetPlaceholderIndex - 1)
            } else {
#if os(macOS)
                NSSound.beep()
#endif
            }
        } else {
            if currentSnippetPlaceholderIndex < activeSnippetPlaceholders.count - 1 {
                selectSnippetPlaceholder(at: currentSnippetPlaceholderIndex + 1)
            } else {
                let endLocation = NSMaxRange(activeSnippetPlaceholders.last?.range ?? selectedRange())
                clearSnippetPlaceholders()
                setSelectedRange(NSRange(location: endLocation, length: 0))
            }
        }

        return true
    }
}
#endif
