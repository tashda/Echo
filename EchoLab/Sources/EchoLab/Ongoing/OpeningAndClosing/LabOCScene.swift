import SwiftUI

/// The state of the mini window and the choreography between its states: launch, connect, open a
/// tab, close it. Each step can be played alone (it first puts the window where that step starts)
/// or the whole story in one go. Every delay is scheduled here, never inside an `Animation`, so
/// Slow motion scales them all alike. The timings come from `LabOCTimings`.
@MainActor @Observable
final class LabOCScene {
    var look = LabOCLook.today
    var motion = EchoMotion()

    var step: LabOCStep = .launch
    var railServer = false
    var treeIn = false
    /// While the welcome fades after a connect, LV1 cancels the columns' push so it stays put.
    var welcomeHoldsPlace = false
    var markPhase: LabOCMarkPhase = .resting
    var welcomeOpacity = 1.0
    var actionsShown = true
    var recentsShown = true
    var serverOpacity = 0.0
    var pieces = LabOCTimings.pieceCount
    var tabOpacity = 0.0
    var tabScale = 1.0
    var captionShown = false
    var caption = ""

    private var generation = 0
    private var factor: Double { look.slow ? 3 : 1 }

    // MARK: - Playing

    /// Plays one step from where it starts.
    func play(_ step: LabOCStep) {
        generation += 1
        prepare(step)
        perform(step, generation)
    }

    /// Plays the whole story: launch, connect, open a tab, close it.
    func playAll() {
        generation += 1
        let gen = generation
        var time = 0.0
        prepare(.launch)
        for step in LabOCStep.allCases {
            run(time, gen) { [self] in perform(step, gen) }
            time += duration(of: step) + 0.9
        }
    }

    /// Shows the window as it is when the app has just opened.
    func showLaunched() {
        generation += 1
        prepare(.connect)
    }

    // MARK: - Steps

    private func perform(_ step: LabOCStep, _ gen: Int) {
        self.step = step
        say(step.caption, gen)
        switch step {
        case .launch: startWelcome(after: 0, gen)
        case .connect: connect(gen)
        case .openTab: openTab(gen)
        case .closeTab: closeTab(gen)
        }
    }

    /// Puts everything where `step` starts, without animating.
    private func prepare(_ step: LabOCStep) {
        still {
            self.step = step
            captionShown = false
            switch step {
            case .launch:
                railServer = false
                treeIn = false
                welcomeHoldsPlace = false
                welcomeOpacity = 1
                serverOpacity = 0
                pieces = LabOCTimings.pieceCount
                tabOpacity = 0
                tabScale = 1
                markPhase = look.mark.animates ? .hidden : .resting
                actionsShown = look.rest == .atOnce
                recentsShown = look.rest == .atOnce
            case .connect:
                prepare(.launch)
                markPhase = .resting
                actionsShown = true
                recentsShown = true
            case .openTab:
                prepare(.connect)
                railServer = true
                treeIn = true
                welcomeOpacity = 0
                serverOpacity = 1
                pieces = LabOCTimings.pieceCount
            case .closeTab:
                prepare(.openTab)
                tabOpacity = 1
                tabScale = 1
                keepsPageUnderTab ? showDestinationUnderTab() : hideDestination()
            }
        }
    }

    private func startWelcome(after delay: Double, _ gen: Int) {
        still {
            markPhase = look.mark.animates ? .hidden : .resting
            actionsShown = look.rest == .atOnce
            recentsShown = look.rest == .atOnce
        }
        let markAt = delay + LabOCTimings.markStart
        if look.mark.animates {
            run(markAt, gen) { [self] in markPhase = .playing(Date()) }
        }
        if look.rest == .rise {
            let riseAt = markAt + LabOCTimings.restDelay
            run(riseAt, gen) { [self] in go(rise) { actionsShown = true } }
            run(riseAt + LabOCTimings.restGap, gen) { [self] in go(rise) { recentsShown = true } }
        }
    }

    private func connect(_ gen: Int) {
        let columns = LabOCTimings.columnsStart(look)
        still {
            pieces = look.arrive == .cascade ? 0 : LabOCTimings.pieceCount
            serverOpacity = look.arrive == .cascade ? 1 : 0
        }

        switch look.leave {
        case .pushed:
            go(motion.standard) { welcomeOpacity = 0 }
        case .stays:
            still { welcomeHoldsPlace = true }
            go(.easeOut(duration: LabOCTimings.stayFade)) { welcomeOpacity = 0 }
            run(1.0, gen) { [self] in still { welcomeHoldsPlace = false } }
        case .pillsOut:
            markPhase = .leaving(Date())
            run(0.1, gen) { [self] in go(.easeOut(duration: 0.2)) { actionsShown = false; recentsShown = false } }
            run(LabOCTimings.leaveTotal, gen) { [self] in still { welcomeOpacity = 0 } }
        }

        run(columns, gen) { [self] in
            go(motion.standard) {
                railServer = true
                if look.columns == .together { treeIn = true }
            }
        }
        if look.columns == .railFirst {
            run(columns + LabOCTimings.treeLag, gen) { [self] in go(motion.standard) { treeIn = true } }
        }

        switch look.arrive {
        case .atOnce:
            run(columns, gen) { [self] in go(motion.standard) { serverOpacity = 1 } }
        case .fadeAfter:
            run(columns + LabOCTimings.columnsDuration - 0.1, gen) { [self] in
                go(.easeOut(duration: LabOCTimings.pageFade)) { serverOpacity = 1 }
            }
        case .cascade:
            buildUpPieces(after: columns + LabOCTimings.cascadeStartOffset, gen)
        }
    }

    private func openTab(_ gen: Int) {
        still { tabOpacity = 0; tabScale = 0.98 }
        go(motion.standard) {
            tabOpacity = 1
            tabScale = 1
            if !keepsPageUnderTab { serverOpacity = 0 }
        }
        if keepsPageUnderTab, look.closeWhere == .welcome {
            run(LabOCTimings.tabFade + 0.05, gen) { [self] in still { showDestinationUnderTab() } }
        }
    }

    private func closeTab(_ gen: Int) {
        let toWelcome = look.closeWhere == .welcome
        switch look.closeHow {
        case .crossfade:
            still { prepareDestinationForArrival(keepingPieces: true) }
            if toWelcome, look.mark.animates { markPhase = .playing(Date()) }
            go(motion.standard) { tabOpacity = 0; tabScale = 0.98; destinationOpacity = 1 }
        case .reveal:
            go(.easeOut(duration: LabOCTimings.revealDuration)) { tabOpacity = 0; tabScale = 0.985 }
        case .cascade:
            still { prepareDestinationForArrival(keepingPieces: false) }
            go(.easeOut(duration: LabOCTimings.leaveCardDuration)) { tabOpacity = 0; tabScale = 0.98 }
            let start = LabOCTimings.leaveCardDuration - 0.05
            if toWelcome {
                run(start, gen) { [self] in destinationOpacity = 1; startWelcome(after: 0, gen) }
            } else {
                still { serverOpacity = 1 }
                buildUpPieces(after: start, gen)
            }
        }
    }

    // MARK: - Pieces of the destination

    /// Where closing the last tab lands.
    private var destinationOpacity: Double {
        get { look.closeWhere == .welcome ? welcomeOpacity : serverOpacity }
        set { if look.closeWhere == .welcome { welcomeOpacity = newValue } else { serverOpacity = newValue } }
    }

    /// Only the reveal keeps the destination mounted under the card.
    private var keepsPageUnderTab: Bool { look.closeHow == .reveal }

    private func showDestinationUnderTab() {
        destinationOpacity = 1
        if look.closeWhere == .welcome {
            markPhase = .resting
            actionsShown = true
            recentsShown = true
        } else {
            pieces = LabOCTimings.pieceCount
        }
    }

    private func hideDestination() {
        welcomeOpacity = 0
        serverOpacity = 0
    }

    private func prepareDestinationForArrival(keepingPieces: Bool) {
        hideDestination()
        pieces = keepingPieces ? LabOCTimings.pieceCount : 0
        if look.closeWhere == .welcome {
            markPhase = look.mark.animates ? .hidden : .resting
            actionsShown = keepingPieces || look.rest == .atOnce
            recentsShown = keepingPieces || look.rest == .atOnce
        }
    }

    private func buildUpPieces(after delay: Double, _ gen: Int) {
        for piece in 1...LabOCTimings.pieceCount {
            run(delay + Double(piece - 1) * LabOCTimings.pieceGap, gen) { [self] in
                go(.smooth(duration: LabOCTimings.pieceDuration)) { pieces = piece }
            }
        }
    }

    // MARK: - Timing helpers

    private var rise: Animation { .smooth(duration: LabOCTimings.riseDuration) }

    private func duration(of step: LabOCStep) -> Double {
        let bars: [LabOCBar] = switch step {
        case .launch: LabOCBars.launch(look) + [LabOCBar(id: "min", row: "", label: "", start: 0, duration: 0.8, role: .fade)]
        case .connect: LabOCBars.connect(look)
        case .openTab: [LabOCBar(id: "open", row: "", label: "", start: 0, duration: LabOCTimings.tabFade, role: .fade)]
        case .closeTab: LabOCBars.close(look)
        }
        return bars.map { $0.start + $0.duration }.max() ?? 0.5
    }

    private func say(_ text: String, _ gen: Int) {
        caption = text
        withAnimation(.easeOut(duration: 0.15)) { captionShown = true }
        run(1.3, gen) { [self] in withAnimation(.easeOut(duration: 0.3)) { captionShown = false } }
    }

    private func run(_ delay: Double, _ gen: Int, _ body: @escaping @MainActor () -> Void) {
        if delay <= 0 {
            body()
            return
        }
        Task(name: "lab-opening-step") { @MainActor [self] in
            try? await Task.sleep(for: .seconds(delay * factor))
            guard gen == generation else { return }
            body()
        }
    }

    private func go(_ animation: Animation, _ body: () -> Void) {
        withAnimation(animation.speed(1 / factor), body)
    }

    private func still(_ body: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, body)
    }
}
