import SwiftUI

/// The card's motions. The edge always glides on `expand` (round 30.2); the dock and the rows
/// follow round 46's choices. A section switch is Echo's own (round 19, S3). Slow motion runs
/// every animation at a third of its speed.
extension LabUFCard {
    private var speed: Double { look.slow ? 1.0 / 3 : 1 }
    private var edge: Animation { motion.expand.speed(speed) }
    private var timing: ExplorerDockSwitchTiming { ExplorerDockSwitchTiming(motion: motion) }

    func iconAnimation(_ index: Int) -> Animation {
        motion.expand.delay((iconsShown ? Double(index) * 0.04 : 0) / speed).speed(speed)
    }

    func rowAnimation(_ index: Int) -> Animation {
        motion.expand.delay((rowsShown ? Double(index) * 0.025 : 0) / speed).speed(speed)
    }

    func toggle() {
        cardOpen ? close() : open()
    }

    /// Close, wait, open: the action button's replay.
    func replay() {
        close()
        Task {
            try? await Task.sleep(for: .seconds(1.2 / speed))
            open()
        }
    }

    func setClosedAtOnce() {
        still { cardOpen = false; dockShown = false; iconsShown = false; rowsShown = false; veil = 0 }
    }

    func open() {
        generation += 1
        let run = generation
        // What is there before the edge starts moving.
        still {
            iconsShown = look.dock != .unfold
            switch look.rows {
            case .atOnce, .drawer: rowsShown = true; veil = 0
            case .veil: rowsShown = true; veil = 1
            case .fadeAfter, .cascade: rowsShown = false; veil = 0
            }
            if look.dock == .atOnce { dockShown = true }
        }
        withAnimation(edge) {
            cardOpen = true
            dockShown = true
            if look.rows == .cascade { rowsShown = true }
        } completion: {
            guard run == generation else { return }
            if look.dock == .unfold { iconsShown = true }
            switch look.rows {
            case .veil: withAnimation(timing.fadeIn.speed(speed)) { veil = 0 }
            case .fadeAfter: withAnimation(timing.fadeIn.speed(speed)) { rowsShown = true }
            default: break
            }
        }
    }

    func close() {
        generation += 1
        let run = generation
        switch look.close {
        case .atOnce:
            still { dockShown = false; iconsShown = false; rowsShown = false }
            withAnimation(edge) { cardOpen = false } completion: { settleClosed(run) }
        case .reverse:
            withAnimation(edge) {
                cardOpen = false
                dockShown = false
                if look.dock == .unfold { iconsShown = false }
                switch look.rows {
                case .veil: veil = 1
                case .fadeAfter, .cascade: rowsShown = false
                case .atOnce: rowsShown = false
                case .drawer: break
                }
            } completion: { settleClosed(run) }
        case .veilThenFold:
            withAnimation(timing.fadeOut.speed(speed)) { veil = 1 } completion: {
                guard run == generation else { return }
                withAnimation(edge) { cardOpen = false; dockShown = false } completion: { settleClosed(run) }
            }
        case .quickFade:
            withAnimation(motion.rowRemoval.speed(speed)) { dockShown = false; rowsShown = false } completion: {
                guard run == generation else { return }
                withAnimation(edge) { cardOpen = false } completion: { settleClosed(run) }
            }
        }
    }

    /// Echo's section switch: the veil fades over the rows, the new section swaps in under it
    /// while the edge settles to its size, then the veil fades away.
    func switchSection(to next: LabUFSection) {
        guard next != section, cardOpen else { return }
        generation += 1
        let run = generation
        withAnimation(timing.fadeOut.speed(speed)) { veil = 1 } completion: {
            guard run == generation else { return }
            withAnimation(motion.dockEdge.speed(speed)) { section = next } completion: {
                guard run == generation else { return }
                withAnimation(timing.fadeIn.speed(speed)) { veil = 0 }
            }
        }
    }

    private func settleClosed(_ run: Int) {
        guard run == generation else { return }
        still { veil = 0; iconsShown = false; rowsShown = false; dockShown = false }
    }

    private func still(_ change: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, change)
    }
}
