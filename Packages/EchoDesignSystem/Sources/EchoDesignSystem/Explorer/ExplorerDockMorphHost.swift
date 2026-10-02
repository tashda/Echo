import SwiftUI

/// Puts a dock row under the morph (`ExplorerDockMorph`). Its place in the tree is the dock's slot;
/// holding it at the top of the view and pushing it out is a visual effect from where the scroll view
/// has it, so a scrolled frame lays nothing out. Only this small view reads the offset, for the
/// progress it hands the dock row through the environment.
public struct ExplorerDockMorphHost: ViewModifier {
    let morph: ExplorerDockMorph
    let scroll: ExplorerTreeScrollState

    public init(morph: ExplorerDockMorph, scroll: ExplorerTreeScrollState) {
        self.morph = morph
        self.scroll = scroll
    }

    public func body(content: Content) -> some View {
        let progress = morph.progress(offset: scroll.offset)
        content
            .environment(\.explorerDockMorph, ExplorerDockMorphState(progress: progress,
                                                                    cornerRadius: morph.cornerRadius(progress: progress)))
            .visualEffect { [morph] effect, proxy in
                effect.offset(y: morph.pinOffset(naturalTop: proxy.frame(in: .scrollView).minY))
            }
    }
}

extension View {
    /// Morphs this dock row into the floating pill as its card scrolls past the top of the tree.
    public func explorerDockMorph(_ morph: ExplorerDockMorph, scroll: ExplorerTreeScrollState) -> some View {
        modifier(ExplorerDockMorphHost(morph: morph, scroll: scroll))
    }
}
