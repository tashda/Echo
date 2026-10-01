import SwiftUI

/// The status pill's popover (round 41.5, PS0): what happened and when, the transaction, and what
/// you can do next: Cancel while running; Show in Editor and Messages after an error; Commit or
/// Roll Back in a transaction (round 21, TA2); Run Again.
struct StatusPillPopover: View {
    @Bindable var query: QueryEditorState
    @Bindable var panelState: BottomPanelState
    /// Commit, Roll Back and Show in Messages while a transaction is open or failed.
    let transactionActions: [BottomPanelStatusBarConfiguration.StatusBubble.MenuItem]

    var body: some View {
        FooterPopoverContent(title: title, width: LayoutTokens.FloatingSurface.mediumWidth) {
            if let error = failureMessage {
                Text(error)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(4)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            FooterPopoverLine(label: "Transaction", value: transactionText)
            if !query.isExecuting {
                FooterPopoverLine(label: "Messages", value: serverMessageCount == 0 ? "None" : serverMessageCount.formatted())
            }
            actions
        }
    }

    private var failureMessage: String? {
        guard !query.isExecuting, let error = query.errorMessage, !error.isEmpty else { return nil }
        return error
    }

    private var title: String {
        if query.isExecuting { return query.cancelPhase != nil ? "Cancelling" : "Running" }
        if query.connectionLoss != nil { return "Disconnected" }
        let at = query.lastRun.map { " at \($0.finishedAt.formatted(date: .omitted, time: .standard))" } ?? ""
        if query.wasCancelled { return "Cancelled" + at }
        if let error = failureMessage {
            return query.failureLine(for: error).map { "Failed on line \($0)" } ?? "Failed" + at
        }
        return "Completed" + at
    }

    private var transactionText: String {
        switch query.transactionState {
        case .none: "None open"
        case .open(let since): "Open since \(since.formatted(date: .omitted, time: .shortened))"
        case .failed: "Failed: roll back"
        }
    }

    private var serverMessageCount: Int { query.messages.count }

    @ViewBuilder
    private var actions: some View {
        let buttons = actionButtons
        if !buttons.isEmpty {
            Divider()
            HStack(spacing: SpacingTokens.xs) {
                ForEach(buttons, id: \.title) { button in
                    Button(button.title, role: button.isDestructive ? .destructive : nil, action: button.action)
                }
                Spacer(minLength: SpacingTokens.none)
            }
            .controlSize(.small)
        }
    }

    private struct Action {
        let title: String
        var isDestructive = false
        let action: () -> Void
    }

    private var actionButtons: [Action] {
        if query.isExecuting {
            return query.cancelPhase == nil ? [Action(title: "Cancel") { query.cancelExecution() }] : []
        }
        var buttons: [Action] = transactionActions
            .filter { $0.title != "Show in Messages" }
            .map { Action(title: $0.title, isDestructive: $0.isDestructive, action: $0.action) }
        if let error = failureMessage, query.failureLine(for: error) != nil {
            buttons.append(Action(title: "Show in Editor") { query.showFailureInEditor(message: error) })
        }
        if failureMessage != nil || !transactionActions.isEmpty || serverMessageCount > 0 {
            buttons.append(Action(title: "Messages") { showMessages() })
        }
        if let rerun = query.rerunAction, query.hasExecutedAtLeastOnce {
            buttons.append(Action(title: "Run Again", action: rerun))
        }
        return buttons
    }

    private func showMessages() {
        panelState.selectedSegment = .messages
        if !panelState.isOpen { panelState.isOpen = true }
    }
}
