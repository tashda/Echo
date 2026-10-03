import SwiftUI
import StageCore

// MARK: - Environment values a specimen can read

private struct StageCornerRadiusKey: EnvironmentKey {
    static let defaultValue: CGFloat = 10
}

private struct StageTextScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

private struct StageReduceMotionKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

private struct StageIncreaseContrastKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

private struct StageTransportTimeKey: EnvironmentKey {
    static let defaultValue: Double? = nil
}

private struct StagePaletteKey: EnvironmentKey {
    static let defaultValue: StagePalette = StagePalette.resolve(dark: false, contrast: false)
}

extension EnvironmentValues {
    /// Corner radius of the surfaces a specimen draws: 10 or 26 (decision H7). Echo's `workspaceCardCornerRadius` maps to this.
    public var stageCornerRadius: CGFloat {
        get { self[StageCornerRadiusKey.self] }
        set { self[StageCornerRadiusKey.self] = newValue }
    }

    /// Multiplier for text sizes (Small 0.9, Default 1, Large 1.15, Extra large 1.3).
    public var stageTextScale: CGFloat {
        get { self[StageTextScaleKey.self] }
        set { self[StageTextScaleKey.self] = newValue }
    }

    /// The owner's Reduce Motion preview switch. A specimen should read this where it would read the system setting.
    public var stageReduceMotion: Bool {
        get { self[StageReduceMotionKey.self] }
        set { self[StageReduceMotionKey.self] = newValue }
    }

    public var stageIncreaseContrast: Bool {
        get { self[StageIncreaseContrastKey.self] }
        set { self[StageIncreaseContrastKey.self] = newValue }
    }

    /// Seconds into the specimen's timeline while the transport bar controls it; `nil` when the specimen runs on its own.
    public var stageTransportTime: Double? {
        get { self[StageTransportTimeKey.self] }
        set { self[StageTransportTimeKey.self] = newValue }
    }

    /// Colours for light, dark and Increase Contrast, so a specimen does not depend on the system appearance.
    public var stagePalette: StagePalette {
        get { self[StagePaletteKey.self] }
        set { self[StagePaletteKey.self] = newValue }
    }
}

// MARK: - Palette (from the prototype's .stg variables)

extension Color {
    init(stageHex hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

public struct StagePalette {
    public let background: Color
    public let card: Color
    public let text: Color
    public let muted: Color
    public let line: Color
    public let accent: Color
    public let error: Color
    public let ok: Color

    public init(background: Color, card: Color, text: Color, muted: Color, line: Color, accent: Color, error: Color, ok: Color) {
        self.background = background; self.card = card; self.text = text; self.muted = muted
        self.line = line; self.accent = accent; self.error = error; self.ok = ok
    }

    public static func resolve(dark: Bool, contrast: Bool) -> StagePalette {
        if contrast {
            return StagePalette(background: Color(stageHex: 0xFFFFFF), card: Color(stageHex: 0xFFFFFF), text: Color(stageHex: 0x000000),
                                muted: Color(stageHex: 0x222222), line: Color(stageHex: 0x000000), accent: Color(stageHex: 0x0030B0),
                                error: Color(stageHex: 0xA00000), ok: Color(stageHex: 0x006400))
        }
        if dark {
            return StagePalette(background: Color(stageHex: 0x12171F), card: Color(stageHex: 0x1E2631), text: Color(stageHex: 0xE9EEF5),
                                muted: Color(stageHex: 0x93A0B2), line: Color(stageHex: 0x2E3948), accent: Color(stageHex: 0x7FA6FF),
                                error: Color(stageHex: 0xFF7B6F), ok: Color(stageHex: 0x5FD08B))
        }
        return StagePalette(background: Color(stageHex: 0xE9EEF3), card: Color(stageHex: 0xFFFFFF), text: Color(stageHex: 0x142033),
                            muted: Color(stageHex: 0x5B6B7E), line: Color(stageHex: 0xD6DEE8), accent: Color(stageHex: 0x2B59C3),
                            error: Color(stageHex: 0xC0362C), ok: Color(stageHex: 0x2E8B57))
    }
}

// MARK: - Flow layout (wraps chips without a sideways scroll)

struct StageFlow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth: CGFloat = proposal.width ?? CGFloat.infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(ProposedViewSize.unspecified)
            if x > 0 && x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(ProposedViewSize.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(width: size.width, height: size.height))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
