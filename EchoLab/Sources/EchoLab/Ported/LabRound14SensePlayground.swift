import AppKit
import SwiftUI

/// Round 14 · ESR4 and ESR5: type on line 1 and use the arrow keys. While typing, the top
/// suggestion is only tinted; once you move with ↑ or ↓ it turns solid, meaning Return inserts it.
struct LabRound14SensePlayground: View {
    @State private var selection: LabSenseSelection = .tintThenSolid
    @State private var corners: LabSenseCorners = .followCards
    @State private var cardCorners: LabCardCornerSetting = .sixteen

    var body: some View {
        LabStage(title: "EchoSense selection and corners") {
            LabPicker(title: "Selection", selection: $selection, options: LabSenseSelection.allCases)
            LabPicker(title: "Popup corners", selection: $corners, options: LabSenseCorners.allCases)
            LabPicker(title: "Card Corners setting", selection: $cardCorners, options: LabCardCornerSetting.allCases)
        } content: {
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                Text("Click line 1 and type (try Cu, Cr, T or Co). Watch the top row while typing, then press ↓ and ↑: with ESR4 the row turns solid only once you choose. Return or Tab inserts, Esc closes. Change Card Corners to see the popup follow the setting; its corner stops at 14pt so the rows inside keep parallel curves.")
                    .font(TypographyTokens.callout)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .frame(width: LayoutTokens.DesignLabRound14.senseEditorWidth, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                LabRound14SenseEditor(selection: selection, corners: corners)
                    .environment(\.workspaceCardCornerRadius, cardCorners.radius)
                    .padding(SpacingTokens.md)
                    .background(ColorTokens.Workspace.canvas, in: .rect(cornerRadius: LayoutTokens.Workspace.cardCornerRadius))
            }
            .padding(SpacingTokens.md)
        }
    }
}

struct LabRound14SenseEditor: View {
    let selection: LabSenseSelection
    let corners: LabSenseCorners

    @State private var text = "SELECT soh.SalesOrderID, Cu"
    @State private var selectedIndex = 0
    @State private var isNavigating = false
    @State private var isDismissed = false
    @State private var ignoresNextChange = false
    @FocusState private var isFocused: Bool
    @Environment(\.workspaceCardCornerRadius) private var cardRadius

    private let gutterWidth = SpacingTokens.xl2
    private let lineHeight = SpacingTokens.md2
    private let lines = ["FROM Sales.SalesOrderHeader AS soh", "JOIN Sales.Customer AS c ON c.CustomerID = soh.CustomerID", "WHERE soh.OrderDate >= '2026-01-01'"]

    private var word: String { String(text.reversed().prefix { $0.isLetter || $0.isNumber || $0 == "_" }.reversed()) }
    private var suggestions: [LabSuggestion] { isDismissed ? [] : LabSuggestion.matches(for: word) }
    private var wordOffset: CGFloat {
        (String(text.dropLast(word.count)) as NSString).size(withAttributes: [.font: TypographyTokens.DesignLabRound14.editorNSFont]).width
    }

    var body: some View {
        LabCard(cornerRadius: cardRadius) {
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: SpacingTokens.none) {
                    editableLine
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        codeLine(number: index + 2) { Text(line).foregroundStyle(ColorTokens.Text.secondary) }
                    }
                }
                .padding(.vertical, SpacingTokens.xs)
                if !suggestions.isEmpty {
                    LabRound14SensePopup(
                        suggestions: suggestions, typed: word, selectedIndex: min(selectedIndex, suggestions.count - 1),
                        isSolid: selection.isSolid(navigating: isNavigating),
                        cornerRadius: corners.popupRadius(cardRadius: cardRadius)
                    ) { index in insert(suggestions[index]) }
                    .offset(x: gutterWidth + SpacingTokens.sm + wordOffset - SpacingTokens.sm, y: SpacingTokens.xs + lineHeight + SpacingTokens.xxs)
                    .transition(.opacity)
                }
            }
        }
        .frame(width: LayoutTokens.DesignLabRound14.senseEditorWidth, height: LayoutTokens.DesignLabRound14.senseEditorHeight)
        .onAppear { isFocused = true }
        .onChange(of: text) {
            if ignoresNextChange { ignoresNextChange = false; return }
            isNavigating = false
            selectedIndex = 0
            isDismissed = false
        }
    }

    private var editableLine: some View {
        codeLine(number: 1) {
            TextField("", text: $text, prompt: Text("Type SQL"))
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onKeyPress(.downArrow) { move(1) }
                .onKeyPress(.upArrow) { move(-1) }
                .onKeyPress(.return) { acceptSelected() }
                .onKeyPress(.tab) { acceptSelected() }
                .onKeyPress(.escape) {
                    guard !suggestions.isEmpty else { return .ignored }
                    isDismissed = true
                    return .handled
                }
        }
    }

    private func codeLine(number: Int, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: SpacingTokens.sm) {
            Text("\(number)")
                .foregroundStyle(ColorTokens.Text.tertiary)
                .frame(width: gutterWidth, alignment: .trailing)
            content()
        }
        .font(TypographyTokens.DesignLabRound14.editor)
        .frame(height: lineHeight)
    }

    private func move(_ step: Int) -> KeyPress.Result {
        guard !suggestions.isEmpty else { return .ignored }
        isNavigating = true
        selectedIndex = (min(selectedIndex, suggestions.count - 1) + step + suggestions.count) % suggestions.count
        return .handled
    }

    private func acceptSelected() -> KeyPress.Result {
        guard !suggestions.isEmpty else { return .ignored }
        insert(suggestions[min(selectedIndex, suggestions.count - 1)])
        return .handled
    }

    private func insert(_ suggestion: LabSuggestion) {
        ignoresNextChange = true
        text = String(text.dropLast(word.count)) + suggestion.insertion
        isDismissed = true
        isNavigating = false
        selectedIndex = 0
    }
}
