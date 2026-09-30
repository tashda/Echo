import SwiftUI

/// The token sheet: colour, type, spacing and motion, drawn live from the shared tokens.
struct FoundationsSpecimen: View {
    enum Sheet: String, CaseIterable, Identifiable {
        case colour = "Colour", type = "Type", spacing = "Spacing", motion = "Motion"
        var id: String { rawValue }
    }

    @State private var sheet: Sheet = .colour

    var body: some View {
        VStack(spacing: SpacingTokens.md) {
            Picker("Sheet", selection: $sheet) {
                ForEach(Sheet.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 320)
            .labelsHidden()
            Group {
                switch sheet {
                case .colour: FoundationsColourSheet()
                case .type: FoundationsTypeSheet()
                case .spacing: FoundationsSpacingSheet()
                case .motion: FoundationsMotionSheet()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(SpacingTokens.lg)
    }
}

private struct FoundationsColourSheet: View {
    private let groups: [(String, [(String, Color)])] = [
        ("Workspace", [("canvas", ColorTokens.Workspace.canvas), ("card", ColorTokens.Workspace.card), ("cardEdge", ColorTokens.Workspace.cardEdge)]),
        ("Sidebar", [("selectedFill", ColorTokens.Sidebar.selectedFill), ("hoverFill", ColorTokens.Sidebar.hoverFill), ("contextFill", ColorTokens.Sidebar.contextFill)]),
        ("Surface", [("rest", ColorTokens.Surface.rest), ("hover", ColorTokens.Surface.hover), ("selected", ColorTokens.Surface.selected)]),
        ("Text", [("primary", ColorTokens.Text.primary), ("secondary", ColorTokens.Text.secondary), ("tertiary", ColorTokens.Text.tertiary)]),
        ("Status", [("success", ColorTokens.Status.success), ("warning", ColorTokens.Status.warning), ("error", ColorTokens.Status.error), ("info", ColorTokens.Status.info)]),
    ]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: SpacingTokens.md, verticalSpacing: SpacingTokens.md) {
            ForEach(groups, id: \.0) { name, swatches in
                GridRow {
                    Text(name).font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                        .frame(width: 80, alignment: .leading)
                    HStack(spacing: SpacingTokens.sm) {
                        ForEach(swatches, id: \.0) { label, color in
                            VStack(spacing: SpacingTokens.xxs) {
                                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(color)
                                    .frame(width: 96, height: 48)
                                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(ColorTokens.Workspace.cardEdge.opacity(0.5), lineWidth: 0.5))
                                Text(label).font(TypographyTokens.detail)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct FoundationsTypeSheet: View {
    private let styles: [(String, String, Font)] = [
        ("title", "System title", TypographyTokens.title),
        ("headline", "Headline", TypographyTokens.headline),
        ("prominent", "Prominent · 14pt", TypographyTokens.prominent),
        ("standard", "Standard · 13pt, most UI", TypographyTokens.standard),
        ("caption2", "Caption · 12pt", TypographyTokens.caption2),
        ("detail", "Detail · 11pt, counts and metadata", TypographyTokens.detail),
        ("label", "Label · 10pt", TypographyTokens.label),
        ("code", "SELECT * FROM orders · 13pt mono", TypographyTokens.code),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            ForEach(styles, id: \.0) { name, sample, font in
                HStack(spacing: SpacingTokens.md) {
                    Text(name).font(.system(size: 11, design: .monospaced)).foregroundStyle(ColorTokens.Text.tertiary)
                        .frame(width: 90, alignment: .leading)
                    Text(sample).font(font)
                }
            }
        }
    }
}

private struct FoundationsSpacingSheet: View {
    private let steps: [(String, CGFloat)] = [
        ("xxxs", SpacingTokens.xxxs), ("xxs", SpacingTokens.xxs), ("xxs2", SpacingTokens.xxs2), ("xs", SpacingTokens.xs),
        ("xs2", SpacingTokens.xs2), ("sm", SpacingTokens.sm), ("md", SpacingTokens.md), ("md2", SpacingTokens.md2), ("lg", SpacingTokens.lg),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            ForEach(steps, id: \.0) { name, value in
                HStack(spacing: SpacingTokens.md) {
                    Text(name).font(.system(size: 11, design: .monospaced)).frame(width: 60, alignment: .leading)
                    Text("\(Int(value))pt").font(TypographyTokens.detail.monospacedDigit()).foregroundStyle(ColorTokens.Text.secondary)
                        .frame(width: 40, alignment: .leading)
                    RoundedRectangle(cornerRadius: 2).fill(ColorTokens.accent).frame(width: value * 8, height: 10)
                }
            }
        }
    }
}

/// Press Play on a row to see that animation run with the stage's speed and Reduce Motion.
private struct FoundationsMotionSheet: View {
    @Environment(\.echoMotion) private var motion

    var body: some View {
        let rows: [(String, Animation)] = [
            ("standard", motion.standard), ("settle", motion.settle), ("hover", motion.hover),
            ("press", motion.press), ("expand", motion.expand), ("reveal", motion.reveal),
        ]
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            ForEach(rows, id: \.0) { name, animation in
                FoundationsMotionRow(name: name, animation: animation)
            }
        }
    }
}

private struct FoundationsMotionRow: View {
    let name: String
    let animation: Animation
    @State private var atEnd = false

    var body: some View {
        HStack(spacing: SpacingTokens.md) {
            Button("Play") { atEnd.toggle() }.controlSize(.small)
            Text(name).font(.system(size: 11, design: .monospaced)).frame(width: 70, alignment: .leading)
            ZStack(alignment: .leading) {
                Capsule().fill(ColorTokens.Surface.hover).frame(width: 360, height: 6)
                Circle().fill(ColorTokens.accent).frame(width: 18, height: 18)
                    .offset(x: atEnd ? 342 : 0)
                    .animation(animation, value: atEnd)
            }
        }
    }
}
