#if os(macOS)
import AppKit

/// Where each line of a script starts, so asking which line a character is on doesn't count the
/// breaks from the top of the script each time (a dozen times per keystroke). A \n, a \r or a \r\n
/// ends a line; a \r\n starts the next line at its \n, which gives the same answers as counting.
struct LineIndex {
    /// The offset where each line begins, the first being 0.
    private(set) var starts: [Int] = [0]
    private(set) var length: Int
    /// A \r was seen: such a script is counted again on each edit, not patched (a \r\n can be split or joined).
    private(set) var hasReturn = false

    init(_ string: NSString) {
        length = string.length
        let capacity = 4096
        let buffer = UnsafeMutablePointer<unichar>.allocate(capacity: capacity)
        defer { buffer.deallocate() }
        var previousWasReturn = false
        var position = 0
        while position < length {
            let count = min(capacity, length - position)
            string.getCharacters(buffer, range: NSRange(location: position, length: count))
            for offset in 0..<count {
                let unit = buffer[offset]
                if unit == 13 {
                    hasReturn = true
                    starts.append(position + offset + 1)
                    previousWasReturn = true
                } else {
                    if unit == 10, !previousWasReturn { starts.append(position + offset + 1) }
                    previousWasReturn = false
                }
            }
            position += count
        }
    }

    /// Patches the index for an edit that replaced `range` (before the edit) with `replacementLength`
    /// characters, now in `string`. Returns false when it can't (a \r is involved): count again then.
    mutating func applyEdit(replacing range: NSRange, replacementLength: Int, in string: NSString) -> Bool {
        guard !hasReturn, range.location != NSNotFound, NSMaxRange(range) <= length,
              string.length == length - range.length + replacementLength else { return false }
        let delta = replacementLength - range.length
        // The starts inside what was replaced go (the line it began on stays); later ones move.
        let lower = firstIndex(withStartAfter: range.location)
        let upper = firstIndex(withStartAfter: NSMaxRange(range))
        starts.removeSubrange(lower..<upper)
        if delta != 0 {
            for index in lower..<starts.count { starts[index] += delta }
        }
        var inserted: [Int] = []
        if replacementLength > 0 {
            let buffer = UnsafeMutablePointer<unichar>.allocate(capacity: replacementLength)
            defer { buffer.deallocate() }
            string.getCharacters(buffer, range: NSRange(location: range.location, length: replacementLength))
            for offset in 0..<replacementLength {
                let unit = buffer[offset]
                if unit == 13 { hasReturn = true; return false }
                if unit == 10 { inserted.append(range.location + offset + 1) }
            }
        }
        starts.insert(contentsOf: inserted, at: lower)
        length = string.length
        return true
    }

    /// The index of the first start after `position`.
    private func firstIndex(withStartAfter position: Int) -> Int {
        var low = 0, high = starts.count
        while low < high {
            let middle = (low + high) / 2
            if starts[middle] <= position { low = middle + 1 } else { high = middle }
        }
        return low
    }

    /// The 1-based line `index` is on (the same as `NSString.lineNumber(at:)`).
    func line(at index: Int) -> Int {
        guard length > 0 else { return 1 }
        let clamped = max(0, min(index, length))
        var low = 0, high = starts.count
        while low < high {
            let middle = (low + high) / 2
            if starts[middle] <= clamped { low = middle + 1 } else { high = middle }
        }
        return low
    }
}

extension SQLTextView {
    /// The 1-based line a character is on, from an index kept until the text changes.
    func lineNumber(at index: Int) -> Int {
        let length = textStorage?.length ?? 0
        // An edit has changed the text but `didChangeText` hasn't run yet (the selection moves first).
        if let lineIndex = lineIndexStorage, lineIndex.length != length, patchLineIndexForPendingEdit() == nil {
            lineIndexStorage = nil
        }
        if let lineIndex = lineIndexStorage, lineIndex.length == length { return lineIndex.line(at: index) }
        // The storage's own string: `string` makes a copy of the whole script, and reading a copy
        // character by character is several times slower.
        let lineIndex = LineIndex(textStorage?.mutableString ?? (string as NSString))
        lineIndexStorage = lineIndex
        return lineIndex.line(at: index)
    }

    /// Called when the text changes with no edit to patch the index with.
    func invalidateLineIndex() {
        lineIndexStorage = nil
        pendingLineEdit = nil
        lineIndexIsPatched = false
    }

    /// Remembers what an edit is about to replace, so the index can be patched. How much came in is read
    /// from the storage afterwards: an attributed string arrives with no replacement string.
    func noteEditForLineIndex(range: NSRange) {
        pendingLineEdit = range
        lineIndexIsPatched = false
    }

    /// Patches the index for the edit noted by `noteEditForLineIndex`, once; nil when it can't.
    private func patchLineIndexForPendingEdit() -> LineIndex? {
        guard var lineIndex = lineIndexStorage, let range = pendingLineEdit, let storage = textStorage else { return nil }
        pendingLineEdit = nil
        let replacementLength = storage.length - (lineIndex.length - range.length)
        guard replacementLength >= 0,
              lineIndex.applyEdit(replacing: range, replacementLength: replacementLength, in: storage.mutableString) else { return nil }
        lineIndexStorage = lineIndex
        lineIndexIsPatched = true
        return lineIndex
    }

    /// `didChangeText`: the index is patched for the edit, or dropped.
    func updateLineIndexAfterEdit() {
        defer { pendingLineEdit = nil; lineIndexIsPatched = false }
        if lineIndexIsPatched { return }
        if patchLineIndexForPendingEdit() == nil { lineIndexStorage = nil }
    }
}
#endif
