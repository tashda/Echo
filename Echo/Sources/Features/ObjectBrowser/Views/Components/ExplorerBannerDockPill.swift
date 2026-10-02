import SwiftUI

/// The title banner's dock row as it morphs into a floating pill while its card scrolls past the top
/// of the tree (round 57, HB3, MT0). At rest it is the banner's bottom row: the banner's colour
/// behind the icons, exactly the slice of the header's gradient that lies under the name. As the
/// morph goes on (`ExplorerDockMorphHost` sets the progress), the colour fades out, a clear glass
/// capsule fades in as the row narrows to the pill and shrinks to its height, and the icons go
/// from the banner's ink to the primary text colour.
struct ExplorerBannerDockPill: View {
    let connectionID: UUID
    let layout: ExplorerDockLayout
    let selectedID: String
    let paint: ServerHeaderPaint
    /// The banner's name block above the dock, and the dock's slot: the gradient's two stretches.
    let nameHeight: CGFloat
    let dockHeight: CGFloat

    @Environment(\.explorerDockMorph) private var morph

    var body: some View {
        let progress = morph?.progress ?? 0
        ExplorerDockMorphLayout(progress: progress) {
            ZStack {
                surface(progress: progress, radius: morph?.cornerRadius ?? 0)
                ExplorerBannerDockRow(connectionID: connectionID, layout: layout, selectedID: selectedID,
                                      ink: paint.ink.mix(with: ColorTokens.Text.primary, by: progress))
            }
        }
    }

    /// The banner colour while it is a row, the glass once it is a pill.
    private func surface(progress: Double, radius: CGFloat) -> some View {
        ZStack {
            if progress < 1 {
                bannerSlice.opacity(1 - progress)
            }
            if progress > 0 {
                Color.clear
                    .glassEffect(.regular, in: .rect(cornerRadius: radius, style: .continuous))
                    .opacity(progress)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The header's backdrop, shifted up by the name block so its lower stretch is what shows: the
    /// gradient and the chosen edge continue from the name block without a seam.
    private var bannerSlice: some View {
        Color.clear.overlay(alignment: .top) {
            ServerHeaderBackdrop(paint: paint, height: nameHeight + dockHeight, isClosed: false)
                .offset(y: -nameHeight)
        }
    }
}
