import SwiftUI
import Combine
import StageCore

/// A specimen drawn at its design size times `scale`. No border, no pins. Used alone, layered, in the Matrix and in the filmstrip.
struct SpecimenCanvas: View {
    @ObservedObject var model: StageModel
    let column: StageColumn
    let scenario: String
    let scale: CGFloat
    var showRedlines: Bool = true
    var allowMotion: Bool = true

    var body: some View {
        let design = model.designSize(for: column)
        content(design: design)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: design.width * scale, height: design.height * scale, alignment: .topLeading)
    }

    /// The transport time reaches the specimen only when it has motion and the owner has used the transport bar.
    private var transportTime: Double? {
        guard allowMotion else { return nil }
        let duration = model.provider.motionDuration(id: column.specimenID, scenario: scenario, controls: column.controls)
        guard duration != nil else { return nil }
        let t = model.state.transport
        return t.engaged ? t.time : nil
    }

    @ViewBuilder
    private func content(design: CGSize) -> some View {
        if model.provider.hasSpecimen(id: column.specimenID) {
            ZStack(alignment: .topLeading) {
                model.provider.specimenView(id: column.specimenID, scenario: scenario, controls: column.controls)
                    .frame(width: design.width, height: design.height, alignment: .top)
                if showRedlines && model.state.redlines {
                    RedlinesOverlay(lines: model.redlines(column, scenario: scenario))
                        .frame(width: design.width, height: design.height, alignment: .topLeading)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: design.width, height: design.height, alignment: .topLeading)
            .environment(\.stageTransportTime, transportTime)
        } else {
            SpecimenFailureView(model: model, column: column)
                .frame(width: design.width, height: design.height)
        }
    }
}

/// The canvas centred in the width it is given.
struct CenteredCanvas: View {
    @ObservedObject var model: StageModel
    let column: StageColumn
    let scale: CGFloat
    var showRedlines: Bool = true

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            SpecimenCanvas(model: model, column: column, scenario: model.state.scenario, scale: scale, showRedlines: showRedlines)
            Spacer(minLength: 0)
        }
    }
}

/// The dashed slot of one column: the specimen at the zoom (100% is Echo's real size, scaled down with a label when too wide),
/// its pins, and the click target for dropping a pin (decisions H9, H13).
struct SpecimenSlot: View {
    @ObservedObject var model: StageModel
    let column: StageColumn
    let scenario: String

    var body: some View {
        let palette = model.palette
        let design = model.designSize(for: column)
        let zoom = StageZoom.clamp(model.state.zoom)
        GeometryReader { geo in
            let avail: Double = Double(max(geo.size.width - 24, 1))
            let fit = StageZoom.effectiveScale(zoom: zoom, designWidth: Double(design.width), available: avail)
            let scale = CGFloat(fit.scale)
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(palette.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    SpecimenCanvas(model: model, column: column, scenario: scenario, scale: scale)
                        .overlay(
                            PinsLayer(model: model, column: column)
                                .frame(width: design.width * scale, height: design.height * scale)
                        )
                    Spacer(minLength: 0)
                }
                .padding(12)
            }
            .overlay(alignment: .bottomTrailing) {
                if fit.fitted {
                    Text("Scaled to \(StageZoom.label(scale: fit.scale)) to fit")
                        .font(.system(size: 10))
                        .foregroundStyle(palette.muted)
                        .padding(6)
                }
            }
        }
        .frame(height: design.height * CGFloat(zoom) + 24)
    }
}

/// Numbered pins on a specimen, and, while pin mode is on, a click target that starts a new one.
struct PinsLayer: View {
    @ObservedObject var model: StageModel
    let column: StageColumn

    private var pins: [StagePin] {
        model.state.pins.filter { $0.option == column.specimenID && $0.x != nil && $0.y != nil }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                if model.state.pinMode {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.06))
                        .contentShape(Rectangle())
                        .gesture(
                            SpatialTapGesture().onEnded { value in
                                let w = max(geo.size.width, 1)
                                let h = max(geo.size.height, 1)
                                model.beginPin(option: column.specimenID, x: Double(value.location.x / w), y: Double(value.location.y / h))
                            }
                        )
                }
                ForEach(pins, id: \.id) { pin in
                    let current: Bool = pin.scenario == model.state.scenario
                    Button {
                        model.send(.openPin(pin.id))
                    } label: {
                        PinBadge(number: pin.number)
                    }
                    .buttonStyle(.plain)
                    .opacity(current ? 1 : 0.4)
                    .help(pin.text)
                    .position(x: CGFloat(pin.x ?? 0) * geo.size.width, y: CGFloat(pin.y ?? 0) * geo.size.height)
                }
            }
        }
    }
}

/// Padding, gaps and sizes drawn over a specimen in its own units (decision H8).
struct RedlinesOverlay: View {
    let lines: [StageRedline]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(lines, id: \.id) { line in
                redline(line)
            }
        }
    }

    @ViewBuilder
    private func redline(_ line: StageRedline) -> some View {
        let outlined: Bool = line.kind == .padding
        // A padding label sits on the top edge of its box so it does not cover the content; gaps and sizes label their own centre.
        let cx: CGFloat = CGFloat(line.x + line.width / 2)
        let cy: CGFloat = CGFloat(line.y + line.height / 2)
        let lx: CGFloat = outlined ? CGFloat(line.x) + 10 : 0
        let ly: CGFloat = outlined ? CGFloat(line.y) - 6 : 0
        ZStack(alignment: .topLeading) {
            shape(line)
                .position(x: cx, y: cy)
            label(line)
                .position(x: outlined ? lx : cx, y: outlined ? ly : cy)
        }
    }

    @ViewBuilder
    private func shape(_ line: StageRedline) -> some View {
        switch line.kind {
        case .padding:
            Rectangle()
                .strokeBorder(Color.red, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                .frame(width: CGFloat(line.width), height: CGFloat(line.height))
        case .gap:
            Rectangle()
                .fill(Color.red.opacity(0.25))
                .frame(width: CGFloat(line.width), height: CGFloat(line.height))
        case .size:
            Rectangle()
                .strokeBorder(Color.red.opacity(0.7), lineWidth: 1)
                .frame(width: CGFloat(line.width), height: CGFloat(line.height))
        }
    }

    private func label(_ line: StageRedline) -> some View {
        Text(line.label)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Color.red)
            .padding(.horizontal, 2)
            .background(Color.white.opacity(0.75))
    }
}

/// Shown in place of a specimen that cannot be drawn; the rest of the stage keeps working (decision H21).
struct SpecimenFailureView: View {
    @ObservedObject var model: StageModel
    let column: StageColumn

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 22))
                .foregroundStyle(model.palette.error)
            Text("\(column.title) did not draw")
                .font(.system(size: 12, weight: .semibold))
            Text("The other specimens still work.")
                .font(.system(size: 11))
                .foregroundStyle(model.palette.muted)
            Button {
                model.reportFailure(column)
            } label: {
                Text("Report to agent")
            }
        }
        .padding(12)
    }
}

/// Where the pin text is typed after clicking a spot.
struct PinComposer: View {
    @ObservedObject var model: StageModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "pin")
                TextField("What do you see here?", text: $model.pinDraftText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { model.commitPinDraft() }
                Button {
                    model.commitPinDraft()
                } label: {
                    Text("Pin")
                }
                .disabled(model.pinDraftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button {
                    model.cancelPinDraft()
                } label: {
                    Text("Cancel")
                }
            }
            Text("The pin keeps the scenario, appearance, corners and zoom you are looking at: \(StageReducer.describe(model.state, manifest: model.manifest))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(10)
        .background(Color(nsColor: NSColor.controlBackgroundColor))
    }
}

/// Play, scrub, frame step, speed 0.25x to 2x, loop, and the timeline of tagged parts (decision H18).
struct TransportBar: View {
    @ObservedObject var model: StageModel
    @State private var lastTick: Date? = nil
    private let timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    private func speedLabel(_ v: Double) -> String {
        v == v.rounded() ? "\(Int(v))×" : "\(v)×"
    }

    var body: some View {
        let duration: Double = model.motionDuration ?? 0
        let transport = model.state.transport
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Button {
                    model.send(.togglePlay(duration: duration))
                } label: {
                    Image(systemName: transport.playing ? "pause.fill" : "play.fill")
                        .frame(width: 18)
                }
                .help("Play or pause")
                Button {
                    model.send(.stepFrames(-1, duration: duration))
                } label: {
                    Image(systemName: "chevron.left")
                }
                .help("Back one frame")
                Button {
                    model.send(.stepFrames(1, duration: duration))
                } label: {
                    Image(systemName: "chevron.right")
                }
                .help("Forward one frame")
                Text(String(format: "%.2f / %.2f s", transport.time, duration))
                    .font(.system(size: 11).monospacedDigit())
                    .frame(width: 104, alignment: .leading)
                Slider(
                    value: Binding<Double>(
                        get: { model.state.transport.time },
                        set: { model.send(.scrub(seconds: $0, duration: duration)) }
                    ),
                    in: 0...max(duration, 0.01)
                )
                Picker("Speed", selection: model.binding({ $0.transport.speed }, { StageAction.setSpeed($0) })) {
                    ForEach(StageTransport.speeds, id: \.self) { v in
                        Text(speedLabel(v)).tag(v)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 70)
                Toggle(isOn: model.binding({ $0.transport.loop }, { _ in StageAction.toggleLoop })) {
                    Image(systemName: "repeat")
                }
                .toggleStyle(.button)
                .help("Loop")
                if model.state.reduceMotion {
                    Text("Reduce Motion on")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            timeline(duration: duration, time: transport.time)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: NSColor.controlBackgroundColor))
        .onReceive(timer) { now in
            tick(now: now, duration: duration)
        }
    }

    private func tick(now: Date, duration: Double) {
        if model.state.transport.playing {
            let dt: Double = lastTick.map { now.timeIntervalSince($0) } ?? 0
            lastTick = now
            model.send(.tick(dt: min(max(dt, 0), 0.1), duration: duration))
        } else if lastTick != nil {
            lastTick = nil
        }
    }

    @ViewBuilder
    private func timeline(duration: Double, time: Double) -> some View {
        let marks = model.motionMarks()
        if !marks.isEmpty && duration > 0 {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(marks, id: \.id) { mark in
                    HStack(spacing: 6) {
                        Text(mark.label)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .frame(width: 110, alignment: .leading)
                        GeometryReader { geo in
                            let w: CGFloat = geo.size.width
                            let start: CGFloat = w * CGFloat(mark.start / duration)
                            let length: CGFloat = max(w * CGFloat((mark.end - mark.start) / duration), 2)
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.secondary.opacity(0.15)).frame(height: 6)
                                Capsule().fill(Color.accentColor).frame(width: length, height: 6).offset(x: start)
                                Rectangle().fill(Color.red).frame(width: 1, height: 10).offset(x: w * CGFloat(time / duration))
                            }
                            .frame(maxHeight: .infinity)
                        }
                        .frame(height: 10)
                    }
                }
            }
        }
    }
}
