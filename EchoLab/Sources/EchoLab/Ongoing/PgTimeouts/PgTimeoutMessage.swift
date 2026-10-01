import SwiftUI

/// What stopped the statement.
enum PgTimeoutReason: Equatable {
    case statement(seconds: Int, scope: String)
    case lock(seconds: Int)
}

/// The message in the tab's results area, where the grid would be, as each "When it fires" option words it.
struct PgTimeoutMessage: View {
    let fired: PgTimeoutsRound.Fired
    let reason: PgTimeoutReason
    var onRunWithoutLimit: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            if fired.explains {
                Label(explanation, systemImage: reason.isLock ? "lock" : "timer")
                    .foregroundStyle(ColorTokens.Status.error)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: SpacingTokens.xs) {
                    Button(reason.isLock ? "Run Again" : "Run Without Limit", action: onRunWithoutLimit)
                    Button("Connection Settings…") {}
                }
                .controlSize(.small)
                Text("Nothing was changed: the statement was rolled back.").foregroundStyle(ColorTokens.Text.tertiary)
            } else if fired == .footer {
                Text("See Messages.").foregroundStyle(ColorTokens.Text.tertiary)
            } else {
                Text(serverText).foregroundStyle(ColorTokens.Status.error)
            }
        }
        .font(TypographyTokens.detail)
        .frame(minWidth: 200, alignment: .leading)
    }

    /// The Messages segment's text for TF3.
    var messagesText: String { "\(serverText)\nLimit: \(limitDescription)" }

    private var serverText: String {
        reason.isLock ? "ERROR: canceling statement due to lock timeout" : "ERROR: canceling statement due to statement timeout"
    }

    private var explanation: String {
        switch reason {
        case let .statement(seconds, scope): "Stopped after \(pgLimitText(seconds)): \(scope)."
        case let .lock(seconds): "Stopped after waiting \(pgLimitText(seconds)) for a lock held by anna (pid 4412: UPDATE orders SET …)."
        }
    }

    private var limitDescription: String {
        switch reason {
        case let .statement(seconds, scope): "\(pgLimitText(seconds)), \(scope)"
        case let .lock(seconds): "lock wait \(pgLimitText(seconds))"
        }
    }
}

extension PgTimeoutReason {
    var isLock: Bool { if case .lock = self { true } else { false } }
}

/// A notification toast at the top right of the card, as round 18 places them.
struct PgTimeoutToast: View {
    let reason: PgTimeoutReason

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.xs) {
            Image(systemName: reason.isLock ? "lock.fill" : "timer")
                .foregroundStyle(ColorTokens.Status.error)
            VStack(alignment: .leading, spacing: SpacingTokens.nano) {
                Text(title).font(TypographyTokens.labelBold)
                Text("localhost · shop. The statement was rolled back.")
                    .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            }
            Spacer(minLength: SpacingTokens.none)
            Button("Show") {}.controlSize(.small)
        }
        .padding(SpacingTokens.sm)
        .frame(width: LayoutTokens.Toast.width)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: LayoutTokens.Toast.cornerRadius, style: .continuous))
        .padding(LayoutTokens.Toast.inset)
    }

    private var title: String {
        switch reason {
        case let .statement(seconds, _): "Query 1 stopped after \(pgLimitText(seconds))"
        case let .lock(seconds): "Query 1 waited \(pgLimitText(seconds)) for a lock"
        }
    }
}

/// "30 s", "5 min", or "No limit".
func pgLimitText(_ seconds: Int?) -> String {
    guard let seconds else { return "No limit" }
    return seconds >= 60 && seconds % 60 == 0 ? "\(seconds / 60) min" : "\(seconds) s"
}
