import SwiftUI
import SQLServerKit

struct QueryStoreStatusBar: View {
    let options: SQLServerQueryStoreOptions

    var body: some View {
        HStack(spacing: SpacingTokens.md) {
            statusBadge
            storageMeter
            configItems
        }
    }

    private var statusBadge: some View {
        HStack(spacing: SpacingTokens.xxs) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text(statusLabel)
                .font(TypographyTokens.detail.weight(.medium))
                .foregroundStyle(ColorTokens.Text.primary)
        }
    }

    private var storageMeter: some View {
        HStack(spacing: SpacingTokens.xs) {
            Text("Storage")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)

            ProgressView(value: usageRatio)
                .frame(width: 80)
                .tint(usageRatio > 0.9 ? ColorTokens.Status.error : ColorTokens.accent)

            Text("\(options.currentStorageSizeMB)/\(options.maxStorageSizeMB) MB")
                .font(TypographyTokens.detail.monospacedDigit())
                .foregroundStyle(ColorTokens.Text.secondary)
        }
    }

    private var configItems: some View {
        HStack(spacing: SpacingTokens.md) {
            labeledValue("Capture", options.queryCaptureMode)
            labeledValue("Flush", "\(options.flushIntervalSeconds)s")
            labeledValue("Stale", "\(options.staleQueryThresholdDays)d")
        }
    }

    private func labeledValue(_ label: String, _ value: String) -> some View {
        HStack(spacing: SpacingTokens.xxxs) {
            Text(label)
                .font(TypographyTokens.compact)
                .foregroundStyle(ColorTokens.Text.quaternary)
            Text(value)
                .font(TypographyTokens.compact.weight(.medium))
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
    }

    private var statusColor: Color {
        if options.isActive { return ColorTokens.Status.success }
        if options.isReadOnly { return ColorTokens.Status.warning }
        return ColorTokens.Status.error
    }

    private var statusLabel: String {
        if options.isActive { return "Active" }
        if options.isReadOnly { return "Read Only" }
        return "Off"
    }

    private var usageRatio: Double {
        guard options.maxStorageSizeMB > 0 else { return 0 }
        return Double(options.currentStorageSizeMB) / Double(options.maxStorageSizeMB)
    }
}
