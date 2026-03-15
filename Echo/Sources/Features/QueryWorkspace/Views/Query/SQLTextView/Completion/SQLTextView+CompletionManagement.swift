#if os(macOS)
import AppKit
import EchoSense

extension SQLTextView {
    func hideCompletions() {
        completionGeneration += 1
        completionWorkItem?.cancel()
        completionWorkItem = nil
        completionTask?.cancel()
        completionTask = nil
        completionController?.hide()
        updateCompletionIndicator()
    }

    func activateManualCompletionSuppression() {
        manualCompletionSuppression = true
        completionGeneration += 1
        completionWorkItem?.cancel()
        completionWorkItem = nil
        completionTask?.cancel()
        completionTask = nil
    }

    func deactivateManualCompletionSuppression() {
        guard manualCompletionSuppression else { return }
        manualCompletionSuppression = false
    }

    func cancelPendingCompletions() {
        hideCompletions()
    }

    @discardableResult
    func ensureCompletionController() -> SQLAutoCompletionController? {
        if completionController == nil {
            completionController = SQLAutoCompletionController(textView: self)
        }
        return completionController
    }

    func consumePopoverSuppressionFlag() -> Bool {
        let value = suppressNextCompletionPopover
        suppressNextCompletionPopover = false
        return value
    }
}
#endif
