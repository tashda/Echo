import SwiftUI

struct SubscriptionEditorOptionsPage: View {
    @Bindable var viewModel: SubscriptionEditorViewModel

    var body: some View {
        Section("Subscription") {
            PropertyRow(
                title: "Enabled",
                info: "Whether the subscription should be actively replicating. Can be toggled after creation."
            ) {
                Toggle("", isOn: $viewModel.enabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            PropertyRow(
                title: "Copy Data",
                info: "When enabled, existing data in the published tables is copied as part of the initial sync."
            ) {
                Toggle("", isOn: $viewModel.copyData)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }

        Section("Replication Slot") {
            PropertyRow(
                title: "Slot Name",
                info: "The name of the replication slot on the publisher. Defaults to the subscription name if left empty."
            ) {
                TextField("", text: $viewModel.slotName, prompt: Text("e.g. my_slot"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        }

        Section("Commit") {
            PropertyRow(
                title: "Synchronous Commit",
                info: "Controls the synchronous_commit setting for the subscription's apply worker."
            ) {
                Picker("", selection: $viewModel.synchronousCommit) {
                    ForEach(SubscriptionSynchronousCommit.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
        }
    }
}
