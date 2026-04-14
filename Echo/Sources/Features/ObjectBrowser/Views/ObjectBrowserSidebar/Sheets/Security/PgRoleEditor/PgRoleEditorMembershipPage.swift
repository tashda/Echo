import SwiftUI

struct PgRoleEditorMembershipPage: View {
    @Bindable var viewModel: PgRoleEditorViewModel

    @State private var selectedMemberOf: Set<UUID> = []
    @State private var selectedMembers: Set<UUID> = []

    private var availableForMemberOf: [String] {
        let existing = Set(viewModel.memberOf.map(\.roleName))
        return viewModel.availableRoles.filter { !existing.contains($0) }
    }

    private var availableForMembers: [String] {
        let existing = Set(viewModel.members.map(\.roleName))
        return viewModel.availableRoles.filter { !existing.contains($0) }
    }

    var body: some View {
        memberOfSection
        if viewModel.isEditing {
            membersSection
        }
    }

    // MARK: - Member Of

    @ViewBuilder
    private var memberOfSection: some View {
        Section("Member Of") {
            membershipTable(
                entries: $viewModel.memberOf,
                selection: $selectedMemberOf,
                availableRoles: availableForMemberOf,
                onAdd: { role in
                    viewModel.memberOf.append(
                        PgRoleMembershipDraft(roleName: role)
                    )
                },
                onRemove: {
                    viewModel.memberOf.removeAll { selectedMemberOf.contains($0.id) }
                    selectedMemberOf.removeAll()
                }
            )
        }
    }

    // MARK: - Members

    @ViewBuilder
    private var membersSection: some View {
        Section("Members") {
            membershipTable(
                entries: $viewModel.members,
                selection: $selectedMembers,
                availableRoles: availableForMembers,
                onAdd: { role in
                    viewModel.members.append(
                        PgRoleMembershipDraft(roleName: role)
                    )
                },
                onRemove: {
                    viewModel.members.removeAll { selectedMembers.contains($0.id) }
                    selectedMembers.removeAll()
                }
            )
        }
    }

    // MARK: - Membership Table

    @ViewBuilder
    private func membershipTable(
        entries: Binding<[PgRoleMembershipDraft]>,
        selection: Binding<Set<UUID>>,
        availableRoles: [String],
        onAdd: @escaping (String) -> Void,
        onRemove: @escaping () -> Void
    ) -> some View {
        Table(entries.wrappedValue, selection: selection) {
            TableColumn("Role") { entry in
                Text(entry.roleName)
                    .font(TypographyTokens.Table.name)
            }
            .width(min: 120, ideal: 180)

            TableColumn("Admin") { entry in
                if let binding = entries.first(where: { $0.wrappedValue.id == entry.id }) {
                    Toggle("", isOn: binding.adminOption)
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                }
            }
            .width(min: 40, ideal: 56)

            TableColumn("Inherit") { entry in
                if let binding = entries.first(where: { $0.wrappedValue.id == entry.id }) {
                    Toggle("", isOn: binding.inheritOption)
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                }
            }
            .width(min: 40, ideal: 56)

            TableColumn("Set") { entry in
                if let binding = entries.first(where: { $0.wrappedValue.id == entry.id }) {
                    Toggle("", isOn: binding.setOption)
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                }
            }
            .width(min: 40, ideal: 56)
        }
        .environment(\.defaultMinListRowHeight, SpacingTokens.lg)
        .frame(minHeight: 60, maxHeight: 200)

        HStack(spacing: SpacingTokens.none) {
            Menu {
                if availableRoles.isEmpty {
                    Text("No roles available")
                } else {
                    ForEach(availableRoles, id: \.self) { role in
                        Button(role) { onAdd(role) }
                    }
                }
            } label: {
                Image(systemName: "plus")
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .frame(width: SpacingTokens.lg, height: SpacingTokens.lg)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .disabled(availableRoles.isEmpty)

            Divider()
                .frame(height: SpacingTokens.sm)

            Button {
                onRemove()
            } label: {
                Image(systemName: "minus")
                    .font(TypographyTokens.standard)
                    .foregroundStyle(
                        selection.wrappedValue.isEmpty
                            ? ColorTokens.Text.quaternary
                            : ColorTokens.Text.secondary
                    )
                    .frame(width: SpacingTokens.lg, height: SpacingTokens.lg)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .fixedSize()
            .disabled(selection.wrappedValue.isEmpty)

            Spacer()
        }
    }
}
