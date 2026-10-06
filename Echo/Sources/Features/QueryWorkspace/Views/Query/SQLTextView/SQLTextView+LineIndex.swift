#if os(macOS)
import AppKit

/// Where each line of a script starts, so asking which line a character is on doesn't count the
/// breaks from the top of the script each time (a dozen times per keystroke). A \n, a \r or a \r\n
/// ends a line; a \r\n starts the next line at its \n, which gives the same answers as counting.
struct LineIndex {
    /// The offset where each line begins, the first being 0.
    private(set) var starts: [Int] = [0]
    let length: Int

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
        if let lineIndex = lineIndexStorage, lineIndex.length == length { return lineIndex.line(at: index) }
        // The storage's own string: `string` makes a copy of the whole script, and reading a copy
        // character by character is several times slower.
        let lineIndex = LineIndex(textStorage?.mutableString ?? (string as NSString))
        lineIndexStorage = lineIndex
        return lineIndex.line(at: index)
    }

    /// Called when the text changes.
    func invalidateLineIndex() { lineIndexStorage = nil }
}
#endif
