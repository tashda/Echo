import SwiftUI
import AppKit
import StageCore

/// The whole window content of a Stage: toolbar, Controls panel, the stage, Decision panel, sheets and keyboard.
public struct StageView: View {
    @ObservedObject var model: StageModel
    @FocusState private var rootFocused: Bool

    public init(model: StageModel) {
        self.model = model
    }

    private var sheetBinding: Binding<Bool> {
        Binding<Bool>(
            get: { model.state.sheet != nil },
            set: { shown in
                if !shown { model.send(.dismissSheet) }
            }
        )
    }

    public var body: some View {
        let scheme: ColorScheme = model.state.appearance == .dark ? .dark : .light
        VStack(spacing: 0) {
            StageToolbar(model: model)
            Divider()
            NoticeBar(model: model)
            panels
        }
        .frame(minWidth: 760, minHeight: 540)
        .background(Color(nsColor: NSColor.windowBackgroundColor))
        .preferredColorScheme(scheme)
        .environment(\.stagePalette, model.palette)
        .environment(\.stageCornerRadius, CGFloat(model.state.corners))
        .environment(\.stageTextScale, CGFloat(model.state.textSize.scale))
        .environment(\.stageReduceMotion, model.state.reduceMotion)
        .environment(\.stageIncreaseContrast, model.state.increaseContrast)
        .focusable()
        .focused($rootFocused)
        .focusEffectDisabled()
        .onKeyPress(phases: .down) { press in
            handle(press)
        }
        .sheet(isPresented: sheetBinding) {
            StageSheets(model: model)
                .preferredColorScheme(scheme)
        }
        .task {
            await model.restore()
            rootFocused = true
        }
    }

    private var panels: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                if !model.state.isFolded(.controls) {
                    ControlsPanel(model: model)
                        .frame(width: 270)
                    Divider()
                }
                StageCenter(model: model)
                    .contentShape(Rectangle())
                    .onTapGesture { rootFocused = true }
                if !model.state.isFolded(.decision) {
                    Divider()
                    DecisionPanel(model: model)
                        .frame(width: 340)
                }
            }
            .onAppear {
                model.send(.autoFold(width: Double(geo.size.width)))
            }
        }
    }

    // MARK: Keyboard (decision H20)

    private func handle(_ press: KeyPress) -> KeyPress.Result {
        let mods = press.modifiers
        if mods.contains(.command) {
            if press.key == .return {
                model.send(.key(mods.contains(.shift) ? .commandShiftReturn : .commandReturn))
                return .handled
            }
            return .ignored
        }
        if mods.contains(.control) || mods.contains(.option) { return .ignored }
        if press.key == .space {
            model.send(.key(.space))
            return .handled
        }
        if press.key == .leftArrow {
            model.send(.key(.left))
            return .handled
        }
        if press.key == .rightArrow {
            model.send(.key(.right))
            return .handled
        }
        let chars = press.characters
        guard chars.count == 1, let ch = chars.first else { return .ignored }
        if let digit = ch.wholeNumberValue, ch.isASCII, digit >= 1, digit <= 5 {
            model.send(.key(.digit(digit)))
            return .handled
        }
        let known: Set<Character> = ["l", "d", "r", "s", "?", "/"]
        if known.contains(Character(String(ch).lowercased())) {
            model.send(.key(.character(ch)))
            return .handled
        }
        return .ignored
    }
}

/// Shows the outcome of Accept or Send back, and a note when Hatch is away.
struct NoticeBar: View {
    @ObservedObject var model: StageModel

    var body: some View {
        VStack(spacing: 0) {
            if let outcome = model.state.outcome {
                bar(text: outcome, symbol: "checkmark.circle") { model.send(.dismissOutcome) }
            }
            if let notice = model.notice {
                bar(text: notice, symbol: "exclamationmark.triangle") { model.dismissNotice() }
            }
            if model.pendingWrites > 0 {
                bar(text: "\(model.pendingWrites) change\(model.pendingWrites == 1 ? "" : "s") waiting for Hatch.", symbol: "clock", close: nil)
            }
        }
    }

    private func bar(text: String, symbol: String, close: (() -> Void)?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
            Text(text).font(.callout)
            Spacer()
            if let close = close {
                Button("Dismiss") { close() }.buttonStyle(.link)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.12))
    }
}
