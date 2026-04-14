import SwiftUI

struct SequenceEditorValuesPage: View {
    @Bindable var viewModel: SequenceEditorViewModel

    var body: some View {
        Section("Increment") {
            PropertyRow(title: "Start With") {
                TextField("", text: $viewModel.startWith, prompt: Text("1"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
            PropertyRow(
                title: "Increment By",
                info: "The step size between sequence values. Negative values create descending sequences."
            ) {
                TextField("", text: $viewModel.incrementBy, prompt: Text("1"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        }

        Section("Bounds") {
            PropertyRow(
                title: "Min Value",
                info: "Leave empty for the default minimum (1 for ascending, min bigint for descending)."
            ) {
                TextField("", text: $viewModel.minValue, prompt: Text("default"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
            PropertyRow(
                title: "Max Value",
                info: "Leave empty for the default maximum (max bigint for ascending, -1 for descending)."
            ) {
                TextField("", text: $viewModel.maxValue, prompt: Text("default"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        }

        Section("Caching") {
            PropertyRow(
                title: "Cache",
                info: "Number of sequence values to pre-allocate in memory. Higher values improve performance but may create gaps."
            ) {
                TextField("", text: $viewModel.cache, prompt: Text("1"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        }

        Section("Options") {
            PropertyRow(
                title: "Cycle",
                info: "When enabled, the sequence wraps around to the minimum value after reaching the maximum (or vice versa for descending)."
            ) {
                Toggle("", isOn: $viewModel.cycle)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }
    }
}
