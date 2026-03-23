import SwiftUI

/// A persistent inline banner indicating the user has read-only access.
///
/// Placed at the top of sheets and detail panes when the current user lacks
/// the permissions required to modify the content below. The banner is
/// non-dismissible — it stays visible as long as the permission restriction applies.
///
/// Usage:
/// ```swift
/// VStack(spacing: 0) {
///     if !canConfigure {
///         PermissionBanner(requiredRole: "sysadmin")
///     }
///     // ... rest of content
/// }
/// ```
struct PermissionBanner: View {
    let requiredRole: String
    var message: String?

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: "lock.fill")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Status.warning)
            Text(message ?? "Read-only — configuration requires the \(requiredRole) role.")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
            Spacer()
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
        .background(ColorTokens.Status.warning.opacity(0.08))
    }
}
