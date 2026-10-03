import SwiftUI
import AppKit
import HatchCore

/// Design tokens from the Hatch design page. Turn colours carry meaning everywhere: amber is the owner's turn, teal an agent's,
/// slate is Hatch itself, green finished, grey paused (decision A5). The status name always sits beside the colour.
enum Theme {
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }

    static let you = dynamic(light: 0xB4540A, dark: 0xF0A25E)
    static let youBackground = dynamic(light: 0xFBEBDD, dark: 0x3A2412)
    static let agent = dynamic(light: 0x0B6E80, dark: 0x4FC3D4)
    static let agentBackground = dynamic(light: 0xDDF0F3, dark: 0x0F3039)
    static let hatch = dynamic(light: 0x4A5B6E, dark: 0xA3B3C8)
    static let hatchBackground = dynamic(light: 0xE4EAF0, dark: 0x1D2B42)
    static let finished = dynamic(light: 0x2D7A46, dark: 0x6CCB8A)
    static let finishedBackground = dynamic(light: 0xE0F1E6, dark: 0x12301E)
    static let paused = dynamic(light: 0x76838F, dark: 0x8697AB)
    static let pausedBackground = dynamic(light: 0xECEFF2, dark: 0x1B2840)
    static let critical = dynamic(light: 0xB3261E, dark: 0xFF8A80)
    static let criticalBackground = dynamic(light: 0xFBE4E2, dark: 0x3C1B19)

    static func color(for turn: Turn) -> Color {
        switch turn {
        case .you: you
        case .agent: agent
        case .hatch: hatch
        case .finished: finished
        case .paused: paused
        }
    }

    static func background(for turn: Turn) -> Color {
        switch turn {
        case .you: youBackground
        case .agent: agentBackground
        case .hatch: hatchBackground
        case .finished: finishedBackground
        case .paused: pausedBackground
        }
    }

    static func symbol(for type: TicketType) -> String {
        switch type {
        case .question: "bubble.left"
        case .sketch: "pencil.and.outline"
        case .proposal: "square.stack.3d.up"
        case .tweak: "slider.horizontal.3"
        case .bug: "ant"
        case .theme: "folder"
        }
    }

    static func turnTitle(_ turn: Turn) -> String {
        switch turn {
        case .you: "Your turn"
        case .agent: "Agent's turn"
        case .hatch: "Hatch"
        case .finished: "Finished"
        case .paused: "Paused"
        }
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
