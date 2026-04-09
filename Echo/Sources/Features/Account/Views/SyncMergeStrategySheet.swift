import SwiftUI

/// Presented when a user enables sync on a project that has both local and cloud data.
/// Lets the user choose how to reconcile the two data sets.
struct SyncMergeStrategySheet: View {
    let summary: SyncDataSummary
    let projectName: String
    let onChoose: (SyncMergeStrategy) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                        Label("Sync Conflict", systemImage: "arrow.triangle.2.circlepath")
                            .font(TypographyTokens.headline)

                        Text("**\(projectName)** has data both on this device and in the cloud. How would you like to proceed?")
                            .font(TypographyTokens.formDescription)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                    .padding(.bottom, SpacingTokens.xs)

                    // Data summary
                    HStack(spacing: SpacingTokens.lg) {
                        dataSummaryColumn(
                            title: "This Device",
                            icon: "laptopcomputer",
                            count: summary.localTotal
                        )

                        Divider()
                            .frame(height: 40)

                        dataSummaryColumn(
                            title: "Cloud",
                            icon: "icloud",
                            count: summary.cloudDocuments
                        )
                    }
                    .padding(.vertical, SpacingTokens.xs)
                }

                Section {
                    strategyButton(
                        title: "Merge Both",
                        description: "Combine local and cloud data. If the same item exists in both, the most recent version wins.",
                        icon: "arrow.triangle.merge",
                        strategy: .merge
                    )

                    strategyButton(
                        title: "Use Cloud",
                        description: "Replace local data with what's in the cloud. Local-only items will be removed.",
                        icon: "icloud.and.arrow.down",
                        strategy: .useCloud
                    )

                    strategyButton(
                        title: "Upload Local",
                        description: "Push local data to the cloud, overwriting cloud versions where they conflict.",
                        icon: "icloud.and.arrow.up",
                        strategy: .uploadLocal
                    )
                }

                Section {
                    Button("Cancel") { dismiss() }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 420, height: 460)
    }

    // MARK: - Components

    private func dataSummaryColumn(title: String, icon: String, count: Int) -> some View {
        VStack(spacing: SpacingTokens.xs) {
            Image(systemName: icon)
                .font(TypographyTokens.prominent)
                .foregroundStyle(ColorTokens.Text.secondary)
            Text("\(count) items")
                .font(TypographyTokens.labelBold)
            Text(title)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func strategyButton(title: String, description: String, icon: String, strategy: SyncMergeStrategy) -> some View {
        Button {
            onChoose(strategy)
            dismiss()
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(description)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .frame(width: 20)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
