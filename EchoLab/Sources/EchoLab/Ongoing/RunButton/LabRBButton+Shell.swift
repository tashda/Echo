import SwiftUI

/// The glass the button sits in, and what is on it. One view for rest, running and the result, so
/// the symbol inside can change in place (replace, magic replace) and the glass can morph.
extension LabRBButton {
    var shell: some View {
        HStack(spacing: SpacingTokens.none) {
            primary
            if showsChevron { chevronMenu.transition(.opacity.combined(with: .move(edge: .leading))) }
        }
        .padding(.horizontal, isWide ? SpacingTokens.xxs2 : SpacingTokens.xxs)
        .padding(.vertical, SpacingTokens.xxxs)
        .overlay { if showsShimmer { LabRBShimmer().clipShape(shape) } }
        .glassEffect(glass, in: shape)
        .glassEffectID(look.change == .morph ? "run" : nil, in: glassSpace)
        .overlay(alignment: .bottom) { note }
    }

    /// The button itself: a plain button, or for M2 a menu that runs on a click and opens on hold.
    @ViewBuilder
    private var primary: some View {
        if look.menu == .hold && !isSample {
            Menu { modeItems } label: { face } primaryAction: { primaryAction() }
                .menuStyle(.button)
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
                .fixedSize()
        } else {
            Button(action: primaryAction) { face }
                .buttonStyle(.plain)
        }
    }

    /// Glyph and words, with a fresh identity per state when the change is a blur or a push.
    @ViewBuilder
    private var face: some View {
        let content = HStack(spacing: SpacingTokens.xxs) {
            LabRBGlyph(button: self)
            if case .running(let started) = visual, look.running.showsTimer {
                LabRBTimerText(started: started, format: look.timerFormat).foregroundStyle(onShell)
            }
            if let words { words }
        }
        .contentShape(Rectangle())
        if look.change == .blur || look.change == .push {
            content.id(visual.kind).transition(transition)
        } else {
            content
        }
    }

    // MARK: Words

    /// The text beside the glyph, if this state has any.
    private var words: Text? {
        switch visual {
        case .running:
            if look.running.showsTimer { return nil }
            return isLabelled ? Text("Stop").foregroundStyle(onShell) : nil
        case .succeeded(let rows, let seconds) where look.result == .rows:
            return Text("\(rows.formatted()) rows · \(seconds.formatted(.number.precision(.fractionLength(1)))) s")
                .foregroundStyle(ColorTokens.Text.primary)
        case .failed(let line) where look.result == .rows:
            return Text("Line \(line)").foregroundStyle(ColorTokens.Text.primary)
        default:
            return restWords
        }
    }

    private var restWords: Text? {
        let title = hasSelection && look.selection == .words ? "Run Selection" : restTitle
        var text: Text?
        switch look.form {
        case .iconTitle: text = Text(title)
        case .titleShortcut: text = Text(title) + Text("  ⌘↩").foregroundStyle(ColorTokens.Text.secondary)
        default:
            if hasSelection && look.selection == .words && !isSample { text = Text("Selection") }
        }
        if look.hover == .reveal && isHovered && !isSample && look.form != .titleShortcut && canRun {
            let shortcut = Text("⌘↩").foregroundStyle(ColorTokens.Text.secondary)
            text = text.map { $0 + Text("  ") + shortcut } ?? shortcut
        }
        return text.map { $0.foregroundStyle(isDimmed ? ColorTokens.Text.tertiary : ColorTokens.Text.primary) }
    }

    private var restTitle: String {
        look.memory == .lastMode && simulation.lastMode != .run ? simulation.lastMode.rawValue : "Run"
    }

    private var isLabelled: Bool { look.form == .iconTitle || look.form == .titleShortcut }

    /// Anything wider than a glyph gets a capsule, even in F6.
    var isWide: Bool {
        if case .running = visual, look.running.showsTimer { return true }
        return words != nil || showsChevron
    }

    // MARK: Glass

    private var shape: AnyShape {
        look.form == .circle && !isWide ? AnyShape(Circle()) : AnyShape(Capsule())
    }

    private var glass: Glass {
        guard let tint = shellTint else { return .regular.interactive() }
        return .regular.tint(tint).interactive()
    }

    /// The glass's colour: solid for prominent looks, a wash for tinted ones, green or red for E3.
    private var shellTint: Color? {
        switch visual {
        case .running:
            if look.running.isProminent { return look.running.fill }
            if look.running == .tintedGlass { return ColorTokens.Status.error.opacity(0.28) }
            return look.form == .prominent ? ColorTokens.Status.error : nil
        case .succeeded where look.result == .flash:
            return ColorTokens.Status.success.opacity(0.4)
        case .failed where look.result == .flash:
            return ColorTokens.Status.error.opacity(0.4)
        default:
            switch look.form {
            case .prominent: return restColour
            case .tintedGlass: return restColour.opacity(0.28)
            default: return nil
            }
        }
    }

    /// The colour of words and glyphs sitting on the glass.
    var onShell: Color {
        if case .running = visual {
            if look.running.isProminent || look.form == .prominent { return LabRBMetrics.onFill }
            return look.running == .quietTimer ? ColorTokens.Text.primary : ColorTokens.Status.error
        }
        return ColorTokens.Text.primary
    }

    /// The colour at rest, after the selection, hover and availability have had their say.
    var restColour: Color {
        if isDimmed { return ColorTokens.Text.tertiary }
        if hasSelection && look.selection == .accentGlyph && !isSample { return ColorTokens.accent }
        if look.hover == .tint && isHovered && !isSample { return ColorTokens.accent }
        return look.colour.color
    }

    // MARK: Menu and note

    private var showsChevron: Bool {
        guard !isSample, !isRunning else { return false }
        return look.menu == .chevron || (look.menu == .hoverChevron && isHovered)
    }

    private var chevronMenu: some View {
        HStack(spacing: SpacingTokens.xxs) {
            Rectangle()
                .fill(ColorTokens.Separator.primary)
                .frame(width: SpacingTokens.micro, height: SpacingTokens.md)
            Menu { modeItems } label: {
                Image(systemName: "chevron.down")
                    .font(TypographyTokens.label.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .frame(height: LabRBMetrics.glyph)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .fixedSize()
        }
        .padding(.trailing, SpacingTokens.xxs)
    }

    /// U3: a click on a Run that can't run says why, under the button.
    @ViewBuilder
    private var note: some View {
        if showsNote {
            Text(editor.reason)
                .font(TypographyTokens.detail)
                .fixedSize()
                .padding(.horizontal, SpacingTokens.xs)
                .padding(.vertical, SpacingTokens.xxs)
                .glassEffect(.regular, in: .capsule)
                .offset(y: LabRBMetrics.glyph + SpacingTokens.xs)
                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top)))
        }
    }

    /// R0 and R5 as Echo draws them today: the system's prominent glass, ■ and the timer.
    func nativeProminent(started: Date) -> some View {
        Button(action: primaryAction) {
            Label {
                LabRBTimerText(started: started, format: look.timerFormat)
            } icon: {
                LabRBGlyph(button: self)
            }
        }
        .labelStyle(.titleAndIcon)
        .buttonStyle(.glassProminent)
        .tint(look.running.fill)
    }

    private var showsShimmer: Bool {
        isRunning && look.runningMotion == .shimmer && motion.allowsLoopingEffects
    }
}

/// The elapsed time in the chosen format, ticking a few times a second.
struct LabRBTimerText: View {
    let started: Date
    let format: LabRBTimerFormat

    var body: some View {
        TimelineView(.periodic(from: started, by: format == .tenths ? 0.1 : 0.5)) { context in
            Text(format.text(max(context.date.timeIntervalSince(started), 0))).monospacedDigit()
        }
    }
}
