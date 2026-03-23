import SwiftUI

/// A persistent inline banner indicating the user lacks permissions.
///
/// Placed at the top of sheets and detail panes when the current user lacks
/// the permissions required to view or modify the content below. The banner is
/// non-dismissible — it stays visible as long as the permission restriction applies.
///
/// Two severity levels:
/// - `.readOnly` — user can view but not modify (yellow/warning)
/// - `.noAccess` — user cannot view or modify at all (red/error)
struct PermissionBanner: View {
    let message: String
    var severity: Severity = .readOnly

    enum Severity {
        case readOnly
        case noAccess
    }

    private var icon: String {
        switch severity {
        case .readOnly: "lock.fill"
        case .noAccess: "lock.shield"
        }
    }

    private var tintColor: Color {
        switch severity {
        case .readOnly: ColorTokens.Status.warning
        case .noAccess: ColorTokens.Status.error
        }
    }

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: icon)
                .font(TypographyTokens.detail)
                .foregroundStyle(tintColor)
            Text(message)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
            Spacer()
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
        .background(tintColor.opacity(0.08))
    }
}
