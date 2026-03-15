import SwiftUI
import SQLServerKit

struct QueryStoreStatusBar: View {
    let options: SQLServerQueryStoreOptions

    var body: some View {
        HStack(spacing: SpacingTokens.lg) {
            statusIndicator
            storageMeter
            Spacer()
            configDetails
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Background.secondary.opacity(0.3))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(ColorTokens.Text.primary.opacity(0.05), lineWidth: 1)
        )
    }

    private var statusIndicator: some View {
        HStack(spacing: SpacingTokens.xs) {
            Circle()
                .fill(options.isActive ? ColorTokens.Status.success : ColorTokens.Status.error)
                .frame(width: 8, height: 8)
            Text(options.actualState)
                .font(TypographyTokens.standard.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.primary)
        }
    }

    private var storageMeter: some View {
        HStack(spacing: SpacingTokens.xs) {
            Text("Storage:")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)

            let usageRatio = options.maxStorageSizeMB > 0
                ? Double(options.currentStorageSizeMB) / Double(options.maxStorageSizeMB)
                : 0

            ProgressView(value: usageRatio)
                .frame(width: 80)
                .tint(usageRatio > 0.9 ? ColorTokens.Status.error : ColorTokens.accent)

            Text("\(options.currentStorageSizeMB)/\(options.maxStorageSizeMB) MB")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
    }

    private var configDetails: some View {
        HStack(spacing: SpacingTokens.md) {
            configItem(label: "Flush", value: "\(options.flushIntervalSeconds)s")
            configItem(label: "Stale", value: "\(options.staleQueryThresholdDays)d")
        }
    }

    private func configItem(label: String, value: String) -> some View {
        HStack(spacing: SpacingTokens.xxxs) {
            Text(label)
                .font(TypographyTokens.compact)
                .foregroundStyle(ColorTokens.Text.tertiary)
            Text(value)
                .font(TypographyTokens.compact.weight(.medium))
                .foregroundStyle(ColorTokens.Text.secondary)
        }
    }
}
