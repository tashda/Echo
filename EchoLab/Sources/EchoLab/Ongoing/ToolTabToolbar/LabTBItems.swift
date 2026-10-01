import SwiftUI

/// One thing in a tab's toolbar section.
enum LabTBItem: Hashable {
    case glyph(LabTBButton)
    /// Run or a main action drawn as a symbol inside a group (RN1, MA0).
    case mainGlyph(LabTBButton)
    /// Run leading its group in a small capsule (RN2).
    case runLead(LabTBButton)
    case picker(String)
    case search(String)
}

/// A capsule of items, or one item that draws its own capsule (Run's red capsule, a worded action).
enum LabTBUnit: Hashable {
    case group([[LabTBItem]])
    case runCapsule(LabTBButton)
    case mainWord(LabTBButton)
}

/// Draws an item in the toolbar's 28pt grid.
struct LabTBItemView: View {
    let item: LabTBItem
    let tab: LabTBTab
    let running: Bool

    var body: some View {
        switch item {
        case .glyph(let button):
            Image(systemName: button.isOn ? button.symbol + ".fill" : button.symbol)
                .font(TypographyTokens.standard)
                .foregroundStyle(button.isOn ? ColorTokens.accent : ColorTokens.Text.primary)
                .frame(width: LayoutTokens.Toolbar.glyph, height: LayoutTokens.Toolbar.glyph)
                .help(button.title)
        case .mainGlyph(let button):
            let symbol = running ? (button.runningSymbol ?? button.symbol) : button.symbol
            Image(systemName: symbol)
                .font(TypographyTokens.standard)
                .foregroundStyle(running && button.runningSymbol != nil ? ColorTokens.Status.error : ColorTokens.Text.primary)
                .frame(width: LayoutTokens.Toolbar.glyph, height: LayoutTokens.Toolbar.glyph)
                .help(running ? (button.runningTitle ?? button.title) : button.title)
        case .runLead(let button):
            let symbol = running ? (button.runningSymbol ?? button.symbol) : button.symbol
            Image(systemName: symbol)
                .font(TypographyTokens.detail.weight(.semibold))
                .foregroundStyle(running ? ColorTokens.Status.error : ColorTokens.accent)
                .frame(width: LayoutTokens.Toolbar.glyph - SpacingTokens.xxs, height: LayoutTokens.Toolbar.glyph - SpacingTokens.xxs)
                .background((running ? ColorTokens.Status.error : ColorTokens.accent).opacity(0.14), in: Capsule())
                .padding(.trailing, SpacingTokens.xxxs)
                .help(running ? "Cancel" : "Run")
        case .picker(let value):
            HStack(spacing: SpacingTokens.xxs) {
                Text(value)
                Image(systemName: "chevron.down").font(TypographyTokens.compact.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
            }
            .font(TypographyTokens.standard)
            .padding(.horizontal, SpacingTokens.xs)
            .frame(height: LayoutTokens.Toolbar.glyph)
        case .search(let prompt):
            HStack(spacing: SpacingTokens.xxs) {
                Image(systemName: "magnifyingglass").foregroundStyle(ColorTokens.Text.secondary)
                Text(prompt).foregroundStyle(ColorTokens.Text.tertiary)
            }
            .font(TypographyTokens.standard)
            .padding(.horizontal, SpacingTokens.xs)
            .frame(width: SpacingTokens.xxxl * 2, height: LayoutTokens.Toolbar.glyph, alignment: .leading)
        }
    }
}

extension LabTBTab {
    /// The tab's toolbar section as units, by the look: Run or the main action first, then the
    /// picker and search when everything moves (MV0), then the button groups.
    func units(_ look: LabTBLook) -> [LabTBUnit] {
        var groups: [[LabTBItem]] = toolbarGroups(look.move).map { $0.map(LabTBItem.glyph) }
        var units: [LabTBUnit] = []
        if let main {
            if isQuery {
                switch look.run {
                case .capsule: units.append(.runCapsule(main))
                case .plain: groups.insert([.mainGlyph(main)], at: 0)
                case .lead: if groups.isEmpty { groups = [[.runLead(main)]] } else { groups[0].insert(.runLead(main), at: 0) }
                }
            } else {
                switch look.mainLook {
                case .word: units.append(.mainWord(main))
                case .symbol: groups.insert([.mainGlyph(main)], at: 0)
                }
            }
        }
        if !isQuery, look.move == .everything {
            if let picker { units.append(.group([[.picker(picker)]])) }
            if let search { units.append(.group([[.search(search)]])) }
        }
        if !groups.isEmpty {
            switch look.groups {
            case .separate, .union, .overflow: units += groups.map { .group([$0]) }
            case .dividers: units.append(.group(groups))
            }
        }
        return units
    }
}
