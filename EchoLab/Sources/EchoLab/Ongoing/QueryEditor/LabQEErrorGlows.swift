import SwiftUI

/// Round 28.6 rev 2: the owner likes the glowing frame and asked for more, beautiful, options. All
/// of them are still (the owner picked MO0 · Still); today's moving glow stays as the first choice.
enum LabQEErrorGlow: String, CaseIterable {
    case today = "GW0 · Three shifting strokes (today)"
    case halo = "GW1 · Soft halo"
    case hairlineHalo = "GW2 · Hairline with a halo"
    case ember = "GW3 · Ember"
    case underglow = "GW4 · Underglow"
    case neon = "GW5 · Neon pill"
    case inner = "GW6 · Inner glow"
    case aura = "GW7 · Aura"
    case doubleRing = "GW8 · Double ring"
    case glowSquiggle = "GW9 · Glow and a squiggle"
    case pillHalo = "GW10 · Pill with a halo"
    case gradientBorder = "GW11 · Gradient border"
    case shadow = "GW12 · Red shadow"

    /// Rev 3: more glows.
    static let addedInRev3: [LabQEErrorGlow] = [.aura, .doubleRing, .glowSquiggle, .pillHalo, .gradientBorder, .shadow]

    var summary: String {
        switch self {
        case .today: "Three blurred strokes of a red gradient that keeps shifting (GlowFrameView)."
        case .halo: "No line at all: a soft red light behind the word, as if it were lit from below the page."
        case .hairlineHalo: "A crisp 1pt red outline with a gentle glow round it: precise and calm."
        case .ember: "Today's red, orange and pink gradient, held still: a warm outline with its own glow."
        case .underglow: "A red glow under the letters only, like a light below the line; the word itself stays clear."
        case .neon: "A capsule round the word, a bright line with a tight glow and a wide faint one."
        case .inner: "A faint red fill whose glow sits inside the frame, fading to the edge."
        case .aura: "A wide, faint red light spreading well past the word, no line."
        case .doubleRing: "Two hairlines, the outer one fainter and further out, like a ripple."
        case .glowSquiggle: "The squiggle under the word with a soft red glow round the whole word."
        case .pillHalo: "A red-tinted capsule with a soft halo round it."
        case .gradientBorder: "A crisp outline running from red to orange; no blur."
        case .shadow: "The word lifts on a soft red shadow below it."
        }
    }
}

/// One still glow round a word's letters (the frame passed in is the letters' rectangle).
struct LabQEStillGlow: View {
    let glow: LabQEErrorGlow
    let corner: CGFloat

    private var red: Color { ColorTokens.Status.error }
    private var ember: AngularGradient {
        AngularGradient(colors: [red, ColorTokens.Status.warning, Color.pink, red], center: .center, angle: .degrees(30))
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: max(corner, SpacingTokens.xxxs), style: .continuous)
        Group {
            switch glow {
            case .today:
                EmptyView()
            case .halo:
                shape.fill(red.opacity(0.35)).blur(radius: 6)
                    .overlay(shape.fill(red.opacity(0.08)))
            case .hairlineHalo:
                ZStack {
                    shape.stroke(red.opacity(0.45), lineWidth: 2).blur(radius: 4)
                    shape.stroke(red.opacity(0.9), lineWidth: 1)
                }
            case .ember:
                ZStack {
                    shape.stroke(ember, lineWidth: 2).blur(radius: 5).opacity(0.6)
                    shape.stroke(ember, lineWidth: 1.2)
                }
            case .underglow:
                Capsule().fill(red.opacity(0.55))
                    .frame(height: SpacingTokens.xxs)
                    .blur(radius: 4)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .offset(y: SpacingTokens.xxxs)
            case .neon:
                ZStack {
                    Capsule().stroke(red.opacity(0.25), lineWidth: 3).blur(radius: 8)
                    Capsule().stroke(red.opacity(0.6), lineWidth: 2).blur(radius: 2)
                    Capsule().stroke(red, lineWidth: 1)
                }
            case .aura:
                shape.fill(red.opacity(0.25)).blur(radius: 12).scaleEffect(1.4)
            case .doubleRing:
                ZStack {
                    shape.stroke(red.opacity(0.85), lineWidth: 1)
                    shape.stroke(red.opacity(0.3), lineWidth: 1).padding(-SpacingTokens.xxxs)
                }
            case .glowSquiggle:
                ZStack(alignment: .bottom) {
                    shape.fill(red.opacity(0.2)).blur(radius: 5)
                    LabQESquiggle().stroke(red, lineWidth: 1).frame(height: SpacingTokens.nano)
                }
            case .pillHalo:
                Capsule().fill(red.opacity(0.14)).background(Capsule().fill(red.opacity(0.3)).blur(radius: 6))
            case .gradientBorder:
                shape.stroke(LinearGradient(colors: [red, ColorTokens.Status.warning], startPoint: .leading, endPoint: .trailing), lineWidth: 1.2)
            case .shadow:
                shape.fill(red.opacity(0.35)).blur(radius: 4).offset(y: SpacingTokens.nano)
            case .inner:
                shape.fill(red.opacity(0.06))
                    .overlay(shape.stroke(red.opacity(0.6), lineWidth: 3).blur(radius: 3).clipShape(shape))
                    .overlay(shape.stroke(red.opacity(0.5), lineWidth: 0.5))
            }
        }
        .allowsHitTesting(false)
    }
}
