#if os(macOS)
import AppKit

/// Round 28.7: while a statement runs its bracket breathes (RR1), and when it ends a line beside
/// what ran fades out over 2 s (H9). Both are layers, so they move without redrawing the gutter.
extension LineNumberRulerView {
    /// Starts or stops the breathing bracket; when a run ends, marks what ran.
    func setRunning(_ lines: ClosedRange<Int>?) {
        let finished = runningLines
        runningLines = lines
        if lines == nil, let finished { showRan(finished) }
        needsDisplay = true
    }

    func showRan(_ lines: ClosedRange<Int>) {
        ranLines = lines
        needsDisplay = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(LayoutTokens.EditorGutter.ranFadeDuration))
            guard let self, self.ranLines == lines else { return }
            self.ranLines = nil
            self.needsDisplay = true
        }
    }

    /// Places (or removes) the layers after the gutter has walked its visible lines.
    func placeRunMarks(_ brackets: StatementBrackets, numbersRight: CGFloat, context: LabelContext) {
        wantsLayer = true
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if let span = brackets.runningSpan {
            let layer = runningLayer ?? makeBarLayer()
            runningLayer = layer
            layer.frame = StatementBrackets.frame(span, numbersRight: numbersRight, context: context)
            if layer.animation(forKey: "breathe") == nil, !reduceMotion {
                let breathe = CABasicAnimation(keyPath: "opacity")
                breathe.fromValue = 1
                breathe.toValue = LayoutTokens.EditorGutter.runningBreathFloor
                breathe.duration = LayoutTokens.EditorGutter.runningBreathDuration / 2
                breathe.autoreverses = true
                breathe.repeatCount = .infinity
                breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                layer.add(breathe, forKey: "breathe")
            }
        } else {
            runningLayer?.removeFromSuperlayer()
            runningLayer = nil
        }
        if let span = brackets.ranSpan {
            let isNew = ranLayer == nil
            let layer = ranLayer ?? makeBarLayer()
            ranLayer = layer
            layer.frame = StatementBrackets.frame(span, numbersRight: numbersRight, context: context)
            if isNew, !reduceMotion {
                layer.opacity = 0
                let fade = CABasicAnimation(keyPath: "opacity")
                fade.fromValue = 1
                fade.toValue = 0
                fade.duration = LayoutTokens.EditorGutter.ranFadeDuration
                fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
                layer.add(fade, forKey: "fade")
            }
        } else {
            ranLayer?.removeFromSuperlayer()
            ranLayer = nil
        }
    }

    private func makeBarLayer() -> CALayer {
        let layer = CALayer()
        layer.backgroundColor = NSColor.controlAccentColor.cgColor
        layer.cornerRadius = LayoutTokens.EditorGutter.statementBracketWidth / 2
        self.layer?.addSublayer(layer)
        return layer
    }
}
#endif
