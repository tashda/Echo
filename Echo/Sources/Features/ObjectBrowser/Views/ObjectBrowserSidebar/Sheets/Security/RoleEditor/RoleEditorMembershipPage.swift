import SwiftUI

struct RoleEditorMembershipPage: View {
    @Bindable var viewModel: RoleEditorViewModel

    var body: some View {
        if viewModel.isLoadingMembers {
            Section {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Loading role members\u{2026}")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        } else if viewModel.memberEntries.isEmpty {
            Section {
                Text("No database principals available.")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        } else {
            Section("Members") {
                ForEach($viewModel.memberEntries) { $entry in
                    PropertyRow(title: entry.name) {
                        Toggle("", isOn: $entry.isMember)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }
            }
        }
    }
}
