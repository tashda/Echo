import SwiftUI

extension PostgresMaintenanceHealthView {

    func cacheHitColor(_ ratio: Double) -> Color {
        if ratio >= 99 { return ColorTokens.Status.success }
        if ratio >= 95 { return ColorTokens.Status.warning }
        return ColorTokens.Status.error
    }

    func connectionColor(_ health: PostgresMaintenanceHealth) -> Color {
        if health.connectionUsagePercent > 80 { return ColorTokens.Status.error }
        if health.connectionUsagePercent > 60 { return ColorTokens.Status.warning }
        return ColorTokens.Text.secondary
    }

    func txidColor(_ severity: PostgresMaintenanceHealth.TxidSeverity) -> Color {
        switch severity {
        case .critical: return ColorTokens.Status.error
        case .warning: return ColorTokens.Status.warning
        case .healthy: return ColorTokens.Status.success
        }
    }

    func formatCount(_ count: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }

    func formatXidAge(_ age: Int64) -> String {
        if age >= 1_000_000_000 { return String(format: "%.2fB", Double(age) / 1_000_000_000) }
        if age >= 1_000_000 { return String(format: "%.0fM", Double(age) / 1_000_000) }
        return "\(age)"
    }

    func formatDuration(_ seconds: Int64) -> String {
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m \(seconds % 60)s" }
        return "\(seconds / 3600)h \((seconds % 3600) / 60)m"
    }
}
