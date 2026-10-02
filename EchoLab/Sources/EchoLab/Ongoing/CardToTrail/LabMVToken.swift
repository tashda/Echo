import SwiftUI

/// Where a flying card is at one moment of its flight, in one of round 54's motions.
struct LabMVPose {
    /// The card's on-screen frame, before any rotation.
    var origin: CGPoint
    /// How much of the card's height shows, in its own points.
    var crop: CGFloat
    var scaleX: CGFloat = 1
    var scaleY: CGFloat = 1
    var card: Double = 1
    var disc: Double = 0
    var discCenter: CGPoint?
    var rollDegrees: Double = 0

    /// The pose for progress `p` (0 at the card, 1 at the trail item; beyond that when it springs).
    static func make(_ motion: LabMVMotion, p: Double, from: CGRect, to: CGRect) -> LabMVPose {
        let headerH: CGFloat = SpacingTokens.xxxl - SpacingTokens.xs
        let discSize = to.size
        let smooth = LabMVEase.smooth
        let phase = LabMVEase.phase
        let lerp = LabMVEase.lerp
        var pose = LabMVPose(origin: from.origin, crop: from.height)
        switch motion {
        case .inPlace:
            let s = 1 - 0.06 * CGFloat(LabMVEase.clamp(p))
            pose.scaleX = s; pose.scaleY = s
            pose.card = 1 - smooth(LabMVEase.clamp(p))
        case .slide:
            pose.origin.x = from.minX - (from.maxX + SpacingTokens.sm) * CGFloat(smooth(LabMVEase.clamp(p)))
            pose.card = 1 - phase(p, 0.35, 1)
        case .ringFirst:
            pose.crop = lerp(from.height, headerH, smooth(LabMVEase.clamp(p)))
            pose.card = 1 - phase(p, 0.4, 1)
        case .shrink:
            let e = smooth(LabMVEase.clamp(p))
            let rect = lerpRect(from, to, p < 0 || p > 1 ? p : e)
            pose = scaled(rect, from: from)
            pose.card = 1 - phase(p, 0.55, 0.95)
            pose.disc = phase(p, 0.45, 0.9) * (1 - phase(p, 0.92, 1))
            pose.discCenter = CGPoint(x: rect.midX, y: rect.midY)
        case .genie:
            let width = lerp(from.width, to.width, smooth(phase(p, 0, 0.6)))
            let height = lerp(from.height, to.height, smooth(phase(p, 0.35, 1)))
            let cx = lerp(from.midX, to.midX, smooth(phase(p, 0.2, 1)))
            let cy = lerp(from.midY, to.midY, smooth(phase(p, 0.2, 1)))
            let rect = CGRect(x: cx - width / 2, y: cy - height / 2, width: width, height: height)
            pose = scaled(rect, from: from)
            pose.card = 1 - phase(p, 0.7, 0.98)
            pose.disc = phase(p, 0.7, 0.95) * (1 - phase(p, 0.95, 1))
            pose.discCenter = CGPoint(x: rect.midX, y: rect.midY)
        case .foldFly, .roll:
            let a = smooth(phase(p, 0, motion == .roll ? 0.5 : 0.42))
            let b = smooth(phase(p, motion == .roll ? 0.5 : 0.42, 1))
            pose.crop = lerp(from.height, headerH, a)
            pose.rollDegrees = motion == .roll ? 55 * a : 0
            if b > 0 {
                let rect = lerpRect(CGRect(x: from.minX, y: from.minY, width: from.width, height: headerH), to, b)
                pose.origin = rect.origin
                pose.crop = headerH
                pose.scaleX = rect.width / from.width
                pose.scaleY = rect.height / headerH
                pose.rollDegrees = motion == .roll ? 55 * (1 - b) : 0
                pose.discCenter = CGPoint(x: rect.midX, y: rect.midY)
            }
            pose.card = 1 - phase(p, 0.6, 0.95)
            pose.disc = phase(p, 0.55, 0.9) * (1 - phase(p, 0.93, 1))
        case .arc:
            let c0 = CGPoint(x: from.minX + discSize.width / 2 + SpacingTokens.sm, y: from.minY + headerH / 2)
            let a = smooth(phase(p, 0, 0.3))
            let start = CGRect(x: c0.x - discSize.width / 2, y: c0.y - discSize.height / 2, width: discSize.width, height: discSize.height)
            let shrunk = lerpRect(from, start, a)
            pose = scaled(shrunk, from: from)
            pose.card = 1 - phase(p, 0.05, 0.3)
            pose.disc = phase(p, 0.1, 0.3) * (1 - phase(p, 0.93, 1))
            var centre = CGPoint(x: shrunk.midX, y: shrunk.midY)
            if p > 0.3 {
                let t = CGFloat(smooth(LabMVEase.clamp((p - 0.3) / 0.7)))
                let control = CGPoint(x: to.midX + (c0.x - to.midX) * 0.2, y: min(c0.y, to.midY) - SpacingTokens.xxxl)
                let one = 1 - t
                centre = CGPoint(x: one * one * c0.x + 2 * one * t * control.x + t * t * to.midX,
                                 y: one * one * c0.y + 2 * one * t * control.y + t * t * to.midY)
            }
            pose.discCenter = centre
        }
        return pose
    }

    private static func lerpRect(_ a: CGRect, _ b: CGRect, _ t: Double) -> CGRect {
        CGRect(x: LabMVEase.lerp(a.minX, b.minX, t), y: LabMVEase.lerp(a.minY, b.minY, t),
               width: LabMVEase.lerp(a.width, b.width, t), height: LabMVEase.lerp(a.height, b.height, t))
    }

    private static func scaled(_ rect: CGRect, from: CGRect) -> LabMVPose {
        var pose = LabMVPose(origin: rect.origin, crop: from.height)
        pose.scaleX = max(rect.width, 1) / from.width
        pose.scaleY = max(rect.height, 1) / from.height
        return pose
    }
}

/// The flying card: the real card at its size, scaled, cropped and rotated into `pose`, with a disc of the
/// server's colour that takes over towards the end.
struct LabMVToken: View {
    let server: LabTIServer
    let pose: LabMVPose
    let from: CGRect
    var rowLimit = 2

    var body: some View {
        ZStack(alignment: .topLeading) {
            if pose.card > 0.001 {
                LabSHCard(server: server.server, look: .today, rowLimit: rowLimit, selectedRow: nil)
                    .frame(width: from.width, height: from.height, alignment: .top)
                    .frame(height: pose.crop, alignment: .top)
                    .clipped()
                    .rotation3DEffect(.degrees(pose.rollDegrees), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.5)
                    .scaleEffect(x: pose.scaleX, y: pose.scaleY, anchor: .topLeading)
                    .offset(x: pose.origin.x, y: pose.origin.y)
                    .opacity(pose.card)
            }
            if pose.disc > 0.001, let centre = pose.discCenter {
                Circle().fill(server.server.color)
                    .frame(width: SpacingTokens.xl, height: SpacingTokens.xl)
                    .overlay {
                        Text(server.monogram).font(.system(size: 12.5, weight: .bold, design: .rounded)).foregroundStyle(ColorTokens.Text.onFill)
                    }
                    .position(x: centre.x, y: centre.y)
                    .opacity(pose.disc)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}
