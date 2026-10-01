import SwiftUI

/// A Health tool's finding (round 37.4, HE0): what is wrong, worst first, with the fix you can run.
nonisolated struct HealthFinding: Identifiable, Equatable, Sendable {
    enum Severity: Int, Comparable, Sendable {
        case problem = 0, warning = 1, fine = 2
        static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// The fix a finding offers; the tool decides what each one runs.
    enum Fix: Equatable, Sendable {
        case backUpNow
        case rebuildIndexes
        case vacuumTables

        var title: String {
            switch self {
            case .backUpNow: "Back Up Now"
            case .rebuildIndexes: "Rebuild"
            case .vacuumTables: "Vacuum"
            }
        }
    }

    let id: String
    let severity: Severity
    let title: String
    let detail: String
    var fix: Fix?

    /// Worst first; the order a tool found them in otherwise.
    static func sorted(_ findings: [HealthFinding]) -> [HealthFinding] {
        findings.enumerated().sorted { ($0.element.severity, $0.offset) < ($1.element.severity, $1.offset) }.map(\.element)
    }
}

/// One finding as a row: its symbol, what is wrong and where, and its fix as a glass capsule.
struct HealthFindingRow: View {
    let finding: HealthFinding
    var isFixing = false
    let onFix: (HealthFinding.Fix) -> Void

    var body: some View {
        HStack(spacing: SpacingTokens.sm) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                Text(finding.title).font(TypographyTokens.standard.weight(.medium))
                Text(finding.detail).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            }
            Spacer(minLength: SpacingTokens.sm)
            if let fix = finding.fix {
                if isFixing {
                    ProgressView().controlSize(.small)
                } else {
                    Button(fix.title) { onFix(fix) }
                        .buttonStyle(.plain)
                        .font(TypographyTokens.detail.weight(.medium))
                        .padding(.horizontal, SpacingTokens.sm)
                        .frame(height: SpacingTokens.lg)
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch finding.severity {
        case .problem: "xmark.octagon.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .fine: "checkmark.circle.fill"
        }
    }

    private var tint: Color {
        switch finding.severity {
        case .problem: ColorTokens.Status.error
        case .warning: ColorTokens.Status.warning
        case .fine: ColorTokens.Status.success
        }
    }
}
