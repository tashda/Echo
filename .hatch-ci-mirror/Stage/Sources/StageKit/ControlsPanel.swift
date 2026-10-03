import SwiftUI
import StageCore

/// Left panel (decision H10): presets on top, decision controls with the recommended star, a folded Playground,
/// which options are shown, and the Mix column.
struct ControlsPanel: View {
    @ObservedObject var model: StageModel

    private var playgroundOpen: Binding<Bool> {
        Binding<Bool>(
            get: { !model.state.isFolded(.playground) },
            set: { _ in model.send(.toggleFold(.playground)) }
        )
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 14) {
                presets
                decisionControls
                playground
                shownOptions
                mixSection
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Presets

    private var presets: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("Presets")
            StageFlow(spacing: 6) {
                if model.manifest.presets.contains(where: { $0.isRecommended }) == false {
                    Button {
                        model.send(.applyRecommendedPreset)
                    } label: {
                        Text("★ Recommended")
                    }
                }
                ForEach(model.manifest.presets, id: \.id) { preset in
                    Button {
                        model.send(.applyPreset(preset.id))
                    } label: {
                        Text(preset.isRecommended ? "★ \(preset.name)" : preset.name)
                    }
                }
                Button {
                    model.send(.resetControls)
                } label: {
                    Text("Reset")
                }
            }
        }
    }

    // MARK: Controls

    private var decisionControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Decision controls")
            if model.manifest.decisionControls.isEmpty {
                Text("This Proposal has no decision controls. Judge the options on the stage.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(model.manifest.decisionControls, id: \.id) { control in
                ControlRow(model: model, control: control)
            }
        }
    }

    private var playground: some View {
        DisclosureGroup(isExpanded: playgroundOpen) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Knobs without a question. They are not part of the decision.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(model.manifest.playgroundControls, id: \.id) { control in
                    ControlRow(model: model, control: control)
                }
                if model.manifest.playgroundControls.isEmpty {
                    Text("Nothing here.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.top, 6)
        } label: {
            SectionLabel("Playground")
        }
    }

    // MARK: Shown options

    @ViewBuilder
    private var shownOptions: some View {
        let options = model.manifest.proposalSpecimens
        if options.count > 1 {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel("Options shown")
                ForEach(options, id: \.id) { option in
                    let isShown: Bool = model.state.shownOptions?.contains(option.id) ?? true
                    Toggle(isOn: Binding<Bool>(
                        get: { isShown },
                        set: { _ in model.send(.toggleShown(option.id)) }
                    )) {
                        HStack(spacing: 4) {
                            Text(option.title)
                            if model.manifest.isNew(addedIn: option.addedIn) { NewBadge() }
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            }
        }
    }

    // MARK: Mix

    private var mixSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("Mix")
            Text("A column drawn from your answers in the Decision panel. Pin it to keep that combination next to the options.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Toggle(isOn: model.binding({ $0.showLiveMix }, { _ in StageAction.toggleLiveMix })) {
                    Text("Show Mix")
                }
                .toggleStyle(.checkbox)
                Spacer()
                Button {
                    model.send(.pinMix)
                } label: {
                    Text("Pin Mix")
                }
            }
            ForEach(model.state.pinnedMixes, id: \.id) { mix in
                HStack {
                    Text(mix.title).font(.callout)
                    Spacer()
                    Button {
                        model.send(.removeMix(mix.id))
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.plain)
                    .help("Remove \(mix.title)")
                }
            }
        }
    }
}

/// One control: title, question, the choices with the recommended star, and what Hatch recommends.
struct ControlRow: View {
    @ObservedObject var model: StageModel
    let control: StageControl

    private var selection: Binding<String> {
        model.binding({ $0.controlValue(control.id, in: model.manifest) }, { StageAction.setControl(id: control.id, value: $0) })
    }

    private func label(for choice: StageChoice) -> String {
        control.recommend == choice.id ? "\(choice.name) ★" : choice.name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(control.title).font(.callout.weight(.semibold))
                if model.manifest.isNew(addedIn: control.addedIn) { NewBadge() }
            }
            if let q = control.question {
                Text(q).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if control.choices.count <= 3 {
                Picker(control.title, selection: selection) {
                    ForEach(control.choices, id: \.id) { choice in
                        Text(label(for: choice)).tag(choice.id)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            } else {
                Picker(control.title, selection: selection) {
                    ForEach(control.choices, id: \.id) { choice in
                        Text(label(for: choice)).tag(choice.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            if let rec = control.recommend {
                let name = control.choices.first(where: { $0.id == rec })?.name ?? rec
                Text("★ Hatch recommends \(name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

struct NewBadge: View {
    var body: some View {
        Text("NEW")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Capsule().fill(Color.accentColor))
    }
}
