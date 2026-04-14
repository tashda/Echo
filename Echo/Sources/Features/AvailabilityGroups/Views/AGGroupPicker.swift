import SwiftUI
import SQLServerKit

struct AGGroupPicker: View {
    @Bindable var viewModel: AvailabilityGroupsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text("Availability Group")
                .font(TypographyTokens.detail.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.secondary)

            HStack(spacing: SpacingTokens.sm) {
                Picker("Group", selection: groupBinding) {
                    ForEach(viewModel.groups) { group in
                        Text(group.name).tag(group.groupId as String?)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 300)

                if let group = viewModel.selectedGroup {
                    groupInfoBadges(group)
                }
            }
        }
    }

    private var groupBinding: Binding<String?> {
        Binding(
            get: { viewModel.selectedGroupId },
            set: { newValue in
                if let id = newValue {
                    Task { await viewModel.selectGroup(id) }
                }
            }
        )
    }

    private func groupInfoBadges(_ group: SQLServerAvailabilityGroup) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            infoBadge(
                label: "Backup",
                value: group.automatedBackupPreference,
                color: ColorTokens.Status.info
            )

            infoBadge(
                label: "Failure Level",
                value: "\(group.failureConditionLevel)",
                color: ColorTokens.Text.secondary
            )
        }
    }

    private func infoBadge(label: String, value: String, color: Color) -> some View {
        HStack(spacing: SpacingTokens.xxs) {
            Text(label)
                .foregroundStyle(ColorTokens.Text.tertiary)
            Text(value)
                .foregroundStyle(color)
        }
        .font(TypographyTokens.detail.weight(.medium))
        .padding(.horizontal, SpacingTokens.xs)
        .padding(.vertical, SpacingTokens.xxs)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(ColorTokens.Background.secondary)
        )
    }
}
