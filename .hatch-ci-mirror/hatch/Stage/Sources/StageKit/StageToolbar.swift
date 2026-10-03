import SwiftUI
import StageCore

/// Two rows that are always visible: the compare mode and tools, then the appearance bar (decisions H3, H7).
struct StageToolbar: View {
    @ObservedObject var model: StageModel

    var body: some View {
        VStack(spacing: 6) {
            toolRow
            appearanceRow
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: Row 1

    private var toolRow: some View {
        HStack(spacing: 10) {
            titleBlock
            Picker("Compare mode", selection: model.binding({ $0.mode }, { StageAction.setMode($0) })) {
                ForEach(StageMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 440)
            .help("Compare mode. Keys 1 to 5.")
            Spacer(minLength: 8)
            zoomControls
            Toggle(isOn: model.binding({ $0.redlines }, { _ in StageAction.toggleRedlines })) {
                Text("Redlines")
            }
            .toggleStyle(.button)
            .help("Draw padding, gaps and sizes. Key R.")
            mixControls
            Toggle(isOn: model.binding({ $0.pinMode }, { _ in StageAction.togglePinMode })) {
                Image(systemName: "pin")
            }
            .toggleStyle(.button)
            .help("Pin a note: switch on, then click the specimen.")
            Button {
                model.send(.requestAsk)
            } label: {
                Label("Ask", systemImage: "questionmark.bubble")
            }
            .buttonStyle(.glass)
            .help("Ask Hatch a question. The current view and state go with it.")
            panelButtons
        }
    }

    /// Kept in its own view so the row stays under SwiftUI's limit of ten children.
    private var panelButtons: some View {
        HStack(spacing: 4) {
            foldButton(panel: .controls, symbol: "sidebar.left", help: "Show or hide Controls")
            foldButton(panel: .decision, symbol: "sidebar.right", help: "Show or hide Decision")
            Button {
                Task { await model.reload() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(model.reloading)
            .help("Reload the Proposal from Hatch. A new revision shows up here.")
            Button {
                model.send(.toggleHelp)
            } label: {
                Image(systemName: "questionmark.circle")
            }
            .help("Keyboard help. Key ?.")
        }
    }

    private var titleBlock: some View {
        HStack(spacing: 6) {
            Text(model.manifest.title.isEmpty ? "Proposal" : model.manifest.title)
                .font(.headline)
                .lineLimit(1)
            revisionControl
        }
    }

    /// The revision switcher (decision H15): the latest revision, or an earlier one with what was added since listed in the
    /// Decision panel. Only a Proposal that has been sent back has more than one.
    @ViewBuilder
    private var revisionControl: some View {
        let latest: Int = model.latestManifest.revision
        if latest > 1 {
            Menu {
                Picker("Revision", selection: model.binding({ $0.viewRevision ?? latest }, { StageAction.setViewRevision($0 >= latest ? nil : $0) })) {
                    ForEach(model.revisionNumbers, id: \.self) { n in
                        Text(revisionTitle(n, latest: latest)).tag(n)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Text("rev \(model.manifest.revision)")
            }
            .menuStyle(.button)
            .menuIndicator(.visible)
            .fixedSize()
            .help("Switch revision. Old options are kept, so your earlier picks still apply.")
        } else {
            Text("rev \(model.manifest.revision)")
                .font(.caption2)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Capsule().fill(Color.secondary.opacity(0.18)))
        }
    }

    private func revisionTitle(_ n: Int, latest: Int) -> String {
        var t = "Revision \(n)"
        if n == latest { t += " (latest)" }
        if let summary = model.revisionSummaries[n], !summary.isEmpty { t += " · \(summary)" }
        return t
    }

    private var zoomControls: some View {
        HStack(spacing: 2) {
            Button {
                model.send(.zoomStep(up: false))
            } label: {
                Image(systemName: "minus")
            }
            .help("Zoom out")
            Button {
                model.send(.setZoom(1.0))
            } label: {
                Text(StageZoom.label(scale: model.state.zoom))
                    .frame(minWidth: 40)
            }
            .help("100% is Echo's real size. Click to reset.")
            Button {
                model.send(.zoomStep(up: true))
            } label: {
                Image(systemName: "plus")
            }
            .help("Zoom in")
        }
    }

    private var mixControls: some View {
        HStack(spacing: 4) {
            Toggle(isOn: model.binding({ $0.showLiveMix }, { _ in StageAction.toggleLiveMix })) {
                Text("Mix")
            }
            .toggleStyle(.button)
            .help("A column drawn from your current answers.")
            Button {
                model.send(.pinMix)
            } label: {
                Text("Pin Mix")
            }
            .help("Keep the current Mix as its own column (Mix 1, Mix 2).")
        }
    }

    private func foldButton(panel: StagePanel, symbol: String, help: String) -> some View {
        Button {
            model.send(.toggleFold(panel))
        } label: {
            Image(systemName: symbol)
        }
        .help(help)
    }

    // MARK: Row 2

    private var appearanceRow: some View {
        HStack(spacing: 10) {
            Picker("Appearance", selection: model.binding({ $0.appearance }, { StageAction.setAppearance($0) })) {
                ForEach(StageAppearance.allCases, id: \.self) { a in
                    Text(a.title).tag(a)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 130)
            .help("Light or Dark. Keys L and D.")
            Toggle(isOn: model.binding({ $0.increaseContrast }, { StageAction.setIncreaseContrast($0) })) {
                Text("Increase Contrast")
            }
            .toggleStyle(.button)
            Picker("Corners", selection: model.binding({ $0.corners }, { StageAction.setCorners($0) })) {
                Text("Corners 10").tag(10)
                Text("Corners 26").tag(26)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 180)
            Picker("Text size", selection: model.binding({ $0.textSize }, { StageAction.setTextSize($0) })) {
                ForEach(StageTextSize.allCases, id: \.self) { t in
                    Text(t.title).tag(t)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)
            Toggle(isOn: model.binding({ $0.reduceMotion }, { StageAction.setReduceMotion($0) })) {
                Text("Reduce Motion")
            }
            .toggleStyle(.button)
            Spacer(minLength: 8)
            Button {
                model.send(.requestSendBack)
            } label: {
                Label("Send back…", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(.glass)
            .keyboardShortcut(.return, modifiers: [.command, .shift])
            .help("Send back with a reason and what to change. Shift-Command-Return.")
            acceptButton
        }
    }

    /// One prominent action per screen (DESIGN.md): this button is prominent only while the Decision panel, which has its own
    /// prominent Accept, is folded away.
    @ViewBuilder
    private var acceptButton: some View {
        if model.state.isFolded(.decision) {
            acceptLabel.buttonStyle(.glassProminent)
        } else {
            acceptLabel.buttonStyle(.glass)
        }
    }

    private var acceptLabel: some View {
        Button {
            model.send(.requestAccept)
        } label: {
            Label("Accept…", systemImage: "checkmark")
        }
        .keyboardShortcut(.return, modifiers: .command)
        .help("Accept. A sheet shows what will change first. Command-Return.")
    }
}
