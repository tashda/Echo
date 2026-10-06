import Foundation
import Testing
@testable import Echo

struct LineIndexTests {
    /// What the editor counted, character by character, before it kept an index.
    private func reference(_ string: NSString, at index: Int) -> Int {
        guard string.length > 0 else { return 1 }
        let clamped = max(0, min(index, string.length))
        var line = 1
        var position = 0
        while position < clamped {
            let currentChar = string.character(at: position)
            if currentChar == 10 {
                line += 1
            } else if currentChar == 13 {
                line += 1
                if position + 1 < clamped && string.character(at: position + 1) == 10 {
                    position += 1
                }
            }
            position += 1
        }
        return line
    }

    @Test func countsEachKindOfLineBreak() {
        let text = "a\nb\r\nc\rd\n\ne" as NSString
        let index = LineIndex(text)
        #expect(index.line(at: 0) == 1)
        #expect(index.line(at: 2) == 2)
        #expect(index.line(at: text.length) == 6)
        #expect(LineIndex("" as NSString).line(at: 10) == 1)
        #expect(index.line(at: -5) == 1)
        #expect(index.line(at: 10_000) == 6)
    }

    @Test func agreesWithTheCharacterByCharacterCountEverywhere() {
        let pieces = ["a", "bc", "\n", "\r", "\r\n", "\n\r", "select 1;", " "]
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            let text = (0..<Int.random(in: 0...80, using: &generator)).map { _ in pieces.randomElement(using: &generator)! }.joined() as NSString
            for index in stride(from: -1, through: text.length + 2, by: 1) {
                #expect(LineIndex(text).line(at: index) == reference(text, at: index), "index \(index) in \(text.debugDescription)")
            }
        }
    }

    @Test func countsAcrossTheChunkSize() {
        let text = String(repeating: "x\r\n", count: 5_000) as NSString
        #expect(LineIndex(text).line(at: text.length) == 5_001)
        // A \r\n split by the end of a chunk is still one break.
        let split = (String(repeating: "y", count: 4_095) + "\r\nz") as NSString
        #expect(LineIndex(split).line(at: split.length) == 2)
        #expect(LineIndex(split).line(at: split.length) == reference(split, at: split.length))
    }

    @Test func aPatchedIndexIsTheIndexOfTheNewText() {
        let pieces = ["a", "bc", "\n", "\n\n", "select 1;", " "]
        var generator = SystemRandomNumberGenerator()
        var patched = 0
        for _ in 0..<400 {
            let old = (0..<Int.random(in: 0...60, using: &generator)).map { _ in pieces.randomElement(using: &generator)! }.joined()
            let oldText = old as NSString
            let location = Int.random(in: 0...oldText.length, using: &generator)
            let length = Int.random(in: 0...(oldText.length - location), using: &generator)
            let replacement = (0..<Int.random(in: 0...6, using: &generator)).map { _ in pieces.randomElement(using: &generator)! }.joined()
            let range = NSRange(location: location, length: length)
            let newText = oldText.replacingCharacters(in: range, with: replacement) as NSString

            var index = LineIndex(oldText)
            guard index.applyEdit(replacing: range, replacementLength: (replacement as NSString).length, in: newText) else { continue }
            patched += 1
            let fresh = LineIndex(newText)
            #expect(index.starts == fresh.starts, "\(old.debugDescription) [\(location),\(length)] -> \(replacement.debugDescription)")
            #expect(index.length == fresh.length)
        }
        #expect(patched > 300)
    }

    @Test func aReturnMakesTheIndexBeCountedAgain() {
        var index = LineIndex("a\r\nb" as NSString)
        let after = "a\r\nbc" as NSString
        #expect(index.applyEdit(replacing: NSRange(location: 4, length: 0), replacementLength: 1, in: after) == false)
        var plain = LineIndex("a\nb" as NSString)
        #expect(plain.applyEdit(replacing: NSRange(location: 3, length: 0), replacementLength: 1, in: "a\nb\r" as NSString) == false)
    }
}
