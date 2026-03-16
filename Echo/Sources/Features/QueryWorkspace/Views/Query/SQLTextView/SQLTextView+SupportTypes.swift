#if os(macOS)
import AppKit
import EchoSense

final class FallbackResponder: NSResponder {
    private let manager = UndoManager()
    override var undoManager: UndoManager? { manager }
    var undoManagerInstance: UndoManager { manager }
}

enum CompletionTriggerKind {
    case none
    case standard
    case immediate
    case evaluateSpace
}

extension NSString {
    func lineNumber(at index: Int) -> Int {
        guard length > 0 else { return 1 }
        let clamped = max(0, min(index, length))
        var line = 1
        var position = 0

        while position < clamped {
            let currentChar = character(at: position)
            if currentChar == 10 { // \n
                line += 1
            } else if currentChar == 13 { // \r
                line += 1
                if position + 1 < clamped && character(at: position + 1) == 10 {
                    position += 1
                }
            }
            position += 1
        }

        return line
    }

    func locationOfLine(_ number: Int) -> Int {
        guard number > 1 else { return 0 }
        var current = 1
        var location = 0
        enumerateSubstrings(in: NSRange(location: 0, length: length), options: [.byLines, .substringNotRequired]) { _, substringRange, _, stop in
            if current == number {
                location = substringRange.location
                stop.pointee = true
            }
            current += 1
        }
        return location
    }

    func endLocationOfLine(_ number: Int) -> Int {
        guard number > 0 else { return 0 }
        var current = 1
        var location = length
        enumerateSubstrings(in: NSRange(location: 0, length: length), options: [.byLines, .substringNotRequired]) { _, substringRange, _, stop in
            if current == number {
                location = NSMaxRange(substringRange)
                stop.pointee = true
            }
            current += 1
        }
        return location
    }
}
#endif
