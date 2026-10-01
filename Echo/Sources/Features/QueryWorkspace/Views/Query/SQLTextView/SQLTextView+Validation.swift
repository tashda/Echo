#if os(macOS)
import AppKit
import SwiftUI
import EchoSense

extension SQLTextView {

    /// Schedule debounced validation if live validation is enabled.
    /// Clears existing overlays immediately so stale annotations don't linger.
    func scheduleValidation() {
        guard displayOptions.liveValidationEnabled else {
            clearValidationDiagnostics()
            return
        }

        // Clear stale overlays immediately — fresh ones appear after debounce
        removeAllValidationOverlays()

        validationScheduler.schedule(
            sql: string,
            context: completionContext
        ) { [weak self] diagnostics in
            guard self?.completionController?.isPresenting != true else { return }
            self?.applyValidationDiagnostics(diagnostics)
        }
    }

    /// Run validation immediately (for on-demand trigger)
    func validateNow() {
        validationScheduler.validateNow(
            sql: string,
            context: completionContext
        ) { [weak self] diagnostics in
            self?.applyValidationDiagnostics(diagnostics)
        }
    }

    private func applyValidationDiagnostics(_ diagnostics: [SQLDiagnostic]) {
        currentDiagnostics = diagnostics
        updateValidationOverlays()
    }

    func clearValidationDiagnostics() {
        validationScheduler.cancel()
        currentDiagnostics = []
        removeAllValidationOverlays()
        lineNumberRuler?.errorLines = []
    }

    func updateValidationOverlays() {
        removeAllValidationOverlays()

        guard !currentDiagnostics.isEmpty else {
            lineNumberRuler?.errorLines = []
            return
        }
        guard layoutManager != nil else { return }

        let text = string as NSString
        let textLength = text.length
        let limitedDiagnostics = Array(currentDiagnostics.prefix(Self.maxValidationOverlays))
        var errorLines = IndexSet()
        defer {
            updateErrorBubbles()
            lineNumberRuler?.errorLines = errorLines
            if displayOptions.outlineEdgeEnabled { outlineStrip?.refresh() }
        }

        for diagnostic in limitedDiagnostics {
            guard let range = resolveRange(for: diagnostic, in: text, textLength: textLength) else {
                continue
            }
            // A red dot in the gutter on each failing line (Design/05-components.md › Editor card).
            errorLines.insert(text.lineNumber(at: range.location))

            // Round 28.6 (E10, SL0): a tinted pill behind the word; the message is in its bubble.
            guard let frame = errorPillRect(for: range) else { continue }
            let pill = ErrorPillView(content: ErrorBubbleContent(diagnostic: diagnostic), line: text.lineNumber(at: range.location))
            pill.frame = frame
            addSubview(pill)
            validationOverlays.append(pill)
        }
    }

    func removeAllValidationOverlays() {
        for overlay in validationOverlays {
            overlay.removeFromSuperview()
        }
        validationOverlays.removeAll()
    }

    private func resolveRange(for diagnostic: SQLDiagnostic, in text: NSString, textLength: Int) -> NSRange? {
        if diagnostic.kind == .syntaxError {
            if let offset = diagnostic.offset {
                let safeOffset = min(offset, textLength)
                let lineRange = text.lineRange(for: NSRange(location: safeOffset, length: 0))
                let lineMax = min(textLength, lineRange.location + lineRange.length)
                var start = min(max(lineRange.location, safeOffset), lineMax)
                while start < lineMax {
                    let character = text.character(at: start)
                    guard let scalar = UnicodeScalar(character) else {
                        break
                    }
                    if !CharacterSet.whitespacesAndNewlines.contains(scalar) { break }
                    start += 1
                }

                var end = start
                while end < lineMax {
                    let character = text.character(at: end)
                    guard let scalar = UnicodeScalar(character),
                          CharacterSet.alphanumerics.contains(scalar) || scalar == UnicodeScalar("_") else {
                        break
                    }
                    end += 1
                }

                if end == start {
                    end = min(lineMax, start + 1)
                }
                let length = end - start
                return length > 0 ? NSRange(location: start, length: max(length, 1)) : nil
            }
            return nil
        }

        let token = diagnostic.token
        guard !token.isEmpty else { return nil }

        let searchRange = NSRange(location: 0, length: textLength)
        let found = text.range(of: token, options: [.caseInsensitive], range: searchRange)
        guard found.location != NSNotFound else { return nil }

        return found
    }
}

#endif
