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
    }

    func updateValidationOverlays() {
        removeAllValidationOverlays()

        guard !currentDiagnostics.isEmpty else { return }
        guard let layoutManager, let textContainer else { return }

        let text = string as NSString
        let textLength = text.length
        let limitedDiagnostics = Array(currentDiagnostics.prefix(Self.maxValidationOverlays))

        for diagnostic in limitedDiagnostics {
            guard let range = resolveRange(for: diagnostic, in: text, textLength: textLength) else {
                continue
            }

            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var tokenRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

            tokenRect.origin.x += textContainerInset.width
            tokenRect.origin.y += textContainerInset.height

            guard tokenRect.width > 0, tokenRect.height > 0 else { continue }

            // Glow frame around the token
            let glowOverlay = ValidationAccessoryView(diagnostic: diagnostic)
            glowOverlay.onActivate = nil
            addSubview(glowOverlay)
            glowOverlay.update(for: tokenRect)
            validationOverlays.append(glowOverlay)

            // Inline annotation after the line end
            let lineEnd = resolveLineEndX(for: range, in: text, layoutManager: layoutManager, textContainer: textContainer)
            let annotationOrigin = NSPoint(
                x: lineEnd + textContainerInset.width + 12,
                y: tokenRect.origin.y
            )
            let annotation = ValidationInlineAnnotation(diagnostic: diagnostic)
            annotation.frame = NSRect(origin: annotationOrigin, size: annotation.intrinsicContentSize)
            addSubview(annotation)
            validationOverlays.append(annotation)
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
                let start = max(0, safeOffset - 1)
                let end = min(textLength, safeOffset + 5)
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

    private func resolveLineEndX(for range: NSRange, in text: NSString, layoutManager: NSLayoutManager, textContainer: NSTextContainer) -> CGFloat {
        let lineRange = text.lineRange(for: NSRange(location: range.location, length: 0))
        let trimmedLength = max(0, lineRange.length - 1)
        let trimmedRange = NSRange(location: lineRange.location, length: max(trimmedLength, 1))
        let lineGlyphRange = layoutManager.glyphRange(forCharacterRange: trimmedRange, actualCharacterRange: nil)
        let lineRect = layoutManager.boundingRect(forGlyphRange: lineGlyphRange, in: textContainer)
        return lineRect.maxX
    }
}

#endif
