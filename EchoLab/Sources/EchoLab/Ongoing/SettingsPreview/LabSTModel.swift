import SwiftUI

/// Settings › Editor's values (GlobalSettings, EditorSettingsView, 2026-10-01), held by one exhibit.
@Observable @MainActor
final class LabSTSettings {
    enum Gutter: String, CaseIterable { case subtle = "Subtle", column = "Column", lane = "Lane", hairline = "Hairline" }
    enum Corners: String, CaseIterable { case square = "Square", rounded = "Rounded", round = "Round Ends" }
    enum Strength: String, CaseIterable { case soft = "Soft", strong = "Strong" }

    var fontSize: Double = 13
    var lineHeight: Double = 1.4
    var lineNumbers = true
    var gutter: Gutter = .subtle
    var statementFocus = true
    var highlightWord = true
    var checkAsYouType = true
    var wrap = true
    var corners: Corners = .round
    var strength: Strength = .soft
    var fullError = false
    var outlineEdge = false
    /// The setting changed last, so the preview can point at what it changed.
    var lastChanged: String?

    func binding<T>(_ keyPath: ReferenceWritableKeyPath<LabSTSettings, T>, _ name: String) -> Binding<T> {
        Binding(get: { self[keyPath: keyPath] }, set: { self[keyPath: keyPath] = $0; self.lastChanged = name })
    }

    func isDefault(_ name: String) -> Bool {
        switch name {
        case "Size": fontSize == 13
        case "Line Height": lineHeight == 1.4
        case "Style": gutter == .subtle
        case "Corners": corners == .round
        case "Strength": strength == .soft
        case "Wrap Long Lines": wrap
        case "Outline Edge": !outlineEdge
        default: true
        }
    }
}

/// A live editor drawn from the settings: gutter style, line numbers, the statement at the caret
/// with its Run arrow, the word at the caret, marks, wrapping, the run note and the outline edge.
struct LabSTPreview: View {
    let settings: LabSTSettings
    var pointsAtChange = false
    @State private var pulse = false

    private let lines = ["select bagno, Centre", "from ba_tbl", "where uniqueBagID <> 123456 and seal is not null and Centre = '10' and state = 0", "",
                         "update aml_checkpoint", "set keyValue = '20260801'"]

    var body: some View {
        let lineHeight = settings.fontSize * settings.lineHeight
        HStack(spacing: SpacingTokens.none) {
            if settings.lineNumbers { gutter(lineHeight: lineHeight) }
            VStack(alignment: .leading, spacing: SpacingTokens.none) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    HStack(spacing: SpacingTokens.xs) {
                        lineText(line, index: index)
                        if index == 2, settings.checkAsYouType {
                            Label(settings.fullError ? "Invalid column name 'seal'" : "Error", systemImage: "exclamationmark.circle.fill")
                                .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.error).lineLimit(1).fixedSize()
                                .padding(.horizontal, SpacingTokens.xs).frame(height: SpacingTokens.md2).glassEffect(.regular, in: .capsule)
                        }
                    }
                    .frame(minHeight: lineHeight, alignment: .leading)
                    .background(alignment: .leading) {
                        if settings.statementFocus, index <= 2 {
                            ColorTokens.accent.opacity(settings.strength == .soft ? 0.06 : 0.12).padding(.leading, -SpacingTokens.xxs)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, SpacingTokens.xs)
            Spacer(minLength: 0)
            if settings.outlineEdge {
                VStack(spacing: SpacingTokens.xxxs) {
                    Capsule().fill(ColorTokens.accent.opacity(0.5)).frame(height: SpacingTokens.lg)
                    Capsule().fill(ColorTokens.Status.error).frame(height: SpacingTokens.xxs)
                    Spacer()
                }
                .frame(width: SpacingTokens.xxs).padding(.vertical, SpacingTokens.xs).padding(.trailing, SpacingTokens.xxs)
                .overlay { highlightRing(for: "Outline Edge") }
            }
        }
        .padding(.vertical, SpacingTokens.xs)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ColorTokens.Workspace.card)
        .clipShape(.rect(cornerRadius: SpacingTokens.sm, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SpacingTokens.sm, style: .continuous).strokeBorder(ColorTokens.Separator.primary, lineWidth: 0.5))
        .onChange(of: settings.lastChanged) { _, _ in
            guard pointsAtChange else { return }
            withAnimation(.easeOut(duration: 0.2)) { pulse = true }
            Task { try? await Task.sleep(for: .seconds(0.9)); withAnimation(.easeIn(duration: 0.4)) { pulse = false } }
        }
    }

    private var radius: CGFloat {
        switch settings.corners {
        case .square: 0
        case .rounded: SpacingTokens.nano
        case .round: SpacingTokens.xs
        }
    }

    private var markOpacity: Double { settings.strength == .soft ? 0.12 : 0.26 }

    @ViewBuilder
    private func lineText(_ line: String, index: Int) -> some View {
        let words = line.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        let wrapped = Text(words.enumerated().reduce(AttributedString()) { result, pair in
            var part = AttributedString((pair.offset == 0 ? "" : " ") + pair.element)
            part.font = .system(size: settings.fontSize, design: .monospaced)
            let lower = pair.element.lowercased()
            if ["select", "from", "where", "update", "set", "and", "is", "not", "null"].contains(lower) { part.foregroundColor = Color(nsColor: .systemBlue) }
            else if pair.element.hasPrefix("'") || Double(pair.element) != nil { part.foregroundColor = Color(nsColor: .systemRed) }
            return result + part
        })
        wrapped
            .lineLimit(settings.wrap ? nil : 1)
            .fixedSize(horizontal: !settings.wrap, vertical: true)
            .background(alignment: .leading) {
                if settings.highlightWord, index == 1 {
                    RoundedRectangle(cornerRadius: radius, style: .continuous).fill(ColorTokens.accent.opacity(markOpacity))
                        .frame(width: settings.fontSize * 3.6, height: settings.fontSize * 1.3).offset(x: settings.fontSize * 2.9)
                        .overlay { highlightRing(for: "Corners").offset(x: settings.fontSize * 2.9).frame(width: settings.fontSize * 3.6) }
                }
            }
    }

    private func gutter(lineHeight: CGFloat) -> some View {
        VStack(alignment: .trailing, spacing: SpacingTokens.none) {
            ForEach(0..<lines.count, id: \.self) { index in
                HStack(spacing: SpacingTokens.xxs) {
                    if settings.statementFocus, index == 0 { Image(systemName: "play.fill").font(TypographyTokens.compact).foregroundStyle(ColorTokens.accent) }
                    Text("\(index + 1)").font(.system(size: settings.fontSize * 0.85, design: .monospaced)).foregroundStyle(ColorTokens.Text.tertiary)
                }
                .frame(height: lineHeight, alignment: .center)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, SpacingTokens.xs)
        .frame(width: SpacingTokens.xl2 + SpacingTokens.xs, alignment: .trailing)
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            switch settings.gutter {
            case .subtle: Color.clear
            case .column: ColorTokens.Sidebar.hoverFill
            case .lane: RoundedRectangle(cornerRadius: SpacingTokens.xs, style: .continuous).fill(ColorTokens.Sidebar.hoverFill).padding(.horizontal, SpacingTokens.xxs).padding(.vertical, -SpacingTokens.xxs)
            case .hairline: HStack { Spacer(); Rectangle().fill(ColorTokens.Separator.primary).frame(width: 0.5) }
            }
        }
        .overlay { highlightRing(for: "Style") }
    }

    @ViewBuilder
    private func highlightRing(for name: String) -> some View {
        if pointsAtChange, pulse, settings.lastChanged == name {
            RoundedRectangle(cornerRadius: SpacingTokens.xs, style: .continuous).strokeBorder(ColorTokens.accent, lineWidth: 2)
                .padding(-SpacingTokens.xxs).allowsHitTesting(false)
        }
    }
}
