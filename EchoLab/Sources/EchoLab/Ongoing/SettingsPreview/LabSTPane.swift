import SwiftUI

/// How a settings page is drawn (round 43).
struct LabSTLook {
    enum Placement: String, CaseIterable {
        case today = "PV0 · One preview near the top that scrolls away (today)"
        case pinned = "PV1 · One preview pinned at the top while the settings scroll"
        case perSection = "PV2 · A small preview in each section, of what that section changes"
        case beside = "PV3 · Settings on the left, a large live preview on the right"
    }

    enum Choices: String, CaseIterable {
        case words = "CH0 · Words in a segmented control or menu (today)"
        case pictures = "CH1 · Small pictures of each choice"
        case wordsPreview = "CH2 · Words; pointing at one shows it in the preview"
    }

    enum Descriptions: String, CaseIterable {
        case under = "DS0 · A grey sentence under the row (today)"
        case short = "DS1 · A short line only where the title isn't enough; the rest in ⓘ"
    }

    enum Feedback: String, CaseIterable {
        case none = "FB0 · The preview just changes (today)"
        case ring = "FB1 · The changed part of the preview is ringed for a moment"
    }

    enum Reset: String, CaseIterable {
        case none = "RS0 · No way back but remembering (today)"
        case perRow = "RS1 · A ↺ beside any setting that isn't the default"
    }

    var placement: Placement = .pinned
    var choices: Choices = .pictures
    var descriptions: Descriptions = .short
    var feedback: Feedback = .ring
    var reset: Reset = .perRow

    static let today = LabSTLook(placement: .today, choices: .words, descriptions: .under, feedback: .none, reset: .none)

    @MainActor static func from(_ v: RoundValues, base: LabSTLook = LabSTLook()) -> LabSTLook {
        var look = base
        if let p = Placement(rawValue: v["placement"]) { look.placement = p }
        if let c = Choices(rawValue: v["choices"]) { look.choices = c }
        if let d = Descriptions(rawValue: v["descriptions"]) { look.descriptions = d }
        if let f = Feedback(rawValue: v["feedback"]) { look.feedback = f }
        if let r = Reset(rawValue: v["reset"]) { look.reset = r }
        return look
    }
}

/// The Settings window with the Editor page, interactive.
struct LabSTWindow: View {
    let look: LabSTLook
    var page = "Editor"
    @State private var settings = LabSTSettings()

    var body: some View {
        HStack(spacing: SpacingTokens.none) {
            LabSTSidebar(selected: page)
            Divider()
            Group {
                switch look.placement {
                case .beside:
                    HStack(spacing: SpacingTokens.none) {
                        form(previews: false).frame(width: 420)
                        LabSTPreview(settings: settings, pointsAtChange: look.feedback == .ring).padding(SpacingTokens.md)
                    }
                case .pinned:
                    VStack(spacing: SpacingTokens.none) {
                        LabSTPreview(settings: settings, pointsAtChange: look.feedback == .ring).frame(height: 160).padding([.horizontal, .top], SpacingTokens.md)
                        form(previews: false)
                    }
                default:
                    form(previews: true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(ColorTokens.Background.primary)
    }

    private func form(previews: Bool) -> some View {
        Form {
            Section("Text") {
                row("Font") { Text("SF Mono ⌄").foregroundStyle(ColorTokens.Text.secondary) }
                row("Size") { Stepper("\(Int(settings.fontSize)) pt", value: settings.binding(\.fontSize, "Size"), in: 10...20) }
                row("Line Height") {
                    Picker("", selection: settings.binding(\.lineHeight, "Line Height")) { ForEach([1.2, 1.4, 1.6], id: \.self) { Text(String(format: "%.1f", $0)).tag($0) } }
                        .labelsHidden().fixedSize()
                }
            }
            if previews, look.placement == .today {
                // Today's EditorFontPreview: the font, size and line height only; nothing else shows.
                Section {
                    VStack(alignment: .leading, spacing: SpacingTokens.none) {
                        ForEach(["SELECT * FROM users", "WHERE created_at > '2026-03-17'", "ORDER BY id DESC"], id: \.self) { line in
                            Text(line).font(.system(size: settings.fontSize, design: .monospaced))
                                .frame(height: settings.fontSize * settings.lineHeight, alignment: .leading)
                        }
                    }
                    .padding(SpacingTokens.sm).frame(maxWidth: .infinity, alignment: .leading)
                    .background(ColorTokens.Workspace.card, in: .rect(cornerRadius: SpacingTokens.xs))
                }
            }
            Section("Gutter") {
                if previews, look.placement == .perSection { LabSTPreview(settings: settings, pointsAtChange: look.feedback == .ring).frame(height: 90) }
                row("Line Numbers") { Toggle("", isOn: settings.binding(\.lineNumbers, "Line Numbers")).labelsHidden().toggleStyle(.switch) }
                row("Style", subtitle: "Subtle shows numbers only; Column adds a faint full-height column; Lane a rounded, inset lane; Hairline only a thin edge.", short: nil) {
                    LabSTChoice(options: LabSTSettings.Gutter.allCases.map(\.rawValue), selection: Binding(get: { settings.gutter.rawValue },
                                set: { settings.gutter = .init(rawValue: $0) ?? .subtle; settings.lastChanged = "Style" }),
                                style: look.choices, picture: { LabSTGutterPicture(style: .init(rawValue: $0) ?? .subtle) })
                }
            }
            Section("While Typing") {
                row("Statement Focus", subtitle: "Mark the statement at the cursor and show a Run arrow beside it.", short: "With a Run arrow beside it") {
                    Toggle("", isOn: settings.binding(\.statementFocus, "Statement Focus")).labelsHidden().toggleStyle(.switch)
                }
                row("Highlight the Word at the Caret") { Toggle("", isOn: settings.binding(\.highlightWord, "Highlight")).labelsHidden().toggleStyle(.switch) }
                row("Wrap Long Lines") { Toggle("", isOn: settings.binding(\.wrap, "Wrap Long Lines")).labelsHidden().toggleStyle(.switch) }
            }
            Section("Marks") {
                if previews, look.placement == .perSection { LabSTPreview(settings: settings, pointsAtChange: look.feedback == .ring).frame(height: 90) }
                row("Corners", subtitle: "Every mark on the text and the selection: the word at the caret, find, mistakes and replacements.", short: nil) {
                    LabSTChoice(options: LabSTSettings.Corners.allCases.map(\.rawValue), selection: Binding(get: { settings.corners.rawValue },
                                set: { settings.corners = .init(rawValue: $0) ?? .round; settings.lastChanged = "Corners" }),
                                style: look.choices, picture: { LabSTMarkPicture(corners: .init(rawValue: $0) ?? .round, strength: settings.strength) })
                }
                row("Strength", subtitle: "How strong every mark's tint is.", short: nil) {
                    LabSTChoice(options: LabSTSettings.Strength.allCases.map(\.rawValue), selection: Binding(get: { settings.strength.rawValue },
                                set: { settings.strength = .init(rawValue: $0) ?? .soft; settings.lastChanged = "Strength" }),
                                style: look.choices, picture: { LabSTMarkPicture(corners: settings.corners, strength: .init(rawValue: $0) ?? .soft) })
                }
            }
            Section("Edges") {
                row("Outline Edge", subtitle: "A strip on the editor's right edge marks statements and errors; click it to jump.", short: "Statements and errors along the right edge") {
                    Toggle("", isOn: settings.binding(\.outlineEdge, "Outline Edge")).labelsHidden().toggleStyle(.switch)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private func row<C: View>(_ title: String, subtitle: String? = nil, short: String? = nil, @ViewBuilder control: () -> C) -> some View {
        let line = look.descriptions == .under ? subtitle : short
        return HStack(alignment: .center, spacing: SpacingTokens.sm) {
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                HStack(spacing: SpacingTokens.xxs) {
                    Text(title)
                    if look.descriptions == .short, subtitle != nil, short == nil {
                        Image(systemName: "info.circle").foregroundStyle(ColorTokens.Text.tertiary).help(subtitle ?? "")
                    }
                }
                if let line { Text(line).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary).fixedSize(horizontal: false, vertical: true) }
            }
            Spacer(minLength: SpacingTokens.xs)
            if look.reset == .perRow, !settings.isDefault(title) {
                Image(systemName: "arrow.uturn.backward.circle").foregroundStyle(ColorTokens.Text.secondary).help("Reset to the default")
            }
            control()
        }
    }
}

/// A choice in words or in pictures.
struct LabSTChoice<Picture: View>: View {
    let options: [String]
    @Binding var selection: String
    let style: LabSTLook.Choices
    @ViewBuilder let picture: (String) -> Picture

    var body: some View {
        switch style {
        case .words, .wordsPreview:
            Picker("", selection: $selection) { ForEach(options, id: \.self) { Text($0).tag($0) } }
                .labelsHidden().pickerStyle(.segmented).fixedSize()
        case .pictures:
            HStack(spacing: SpacingTokens.xs) {
                ForEach(options, id: \.self) { option in
                    VStack(spacing: SpacingTokens.xxs) {
                        picture(option)
                            .frame(width: SpacingTokens.xxxl - SpacingTokens.xs, height: SpacingTokens.xl2)
                            .background(ColorTokens.Workspace.card, in: .rect(cornerRadius: SpacingTokens.xs))
                            .overlay(RoundedRectangle(cornerRadius: SpacingTokens.xs).strokeBorder(option == selection ? ColorTokens.accent : ColorTokens.Separator.primary,
                                                                                                    lineWidth: option == selection ? 2 : 0.5))
                        Text(option).font(TypographyTokens.detail).foregroundStyle(option == selection ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
                    }
                    .onTapGesture { selection = option }
                }
            }
        }
    }
}

/// A gutter style, drawn small.
struct LabSTGutterPicture: View {
    let style: LabSTSettings.Gutter
    var body: some View {
        HStack(spacing: SpacingTokens.xxs) {
            VStack(alignment: .trailing, spacing: SpacingTokens.xxxs) { ForEach(1..<4) { Text("\($0)").font(TypographyTokens.compact.monospaced()).foregroundStyle(ColorTokens.Text.tertiary) } }
                .padding(.horizontal, SpacingTokens.xxs).frame(maxHeight: .infinity)
                .background {
                    switch style {
                    case .subtle: Color.clear
                    case .column: ColorTokens.Sidebar.selectedFill
                    case .lane: RoundedRectangle(cornerRadius: SpacingTokens.xxs).fill(ColorTokens.Sidebar.selectedFill).padding(SpacingTokens.xxxs)
                    case .hairline: HStack { Spacer(); Rectangle().fill(ColorTokens.Separator.primary).frame(width: 1) }
                    }
                }
            VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                ForEach([0.8, 0.5, 0.65], id: \.self) { width in Capsule().fill(ColorTokens.Text.tertiary.opacity(0.4)).frame(width: 30 * width, height: 3) }
            }
            Spacer(minLength: 0)
        }
        .clipShape(.rect(cornerRadius: SpacingTokens.xs))
    }
}

/// A mark (the word at the caret), drawn small.
struct LabSTMarkPicture: View {
    let corners: LabSTSettings.Corners
    let strength: LabSTSettings.Strength
    var body: some View {
        Text("bagno").font(TypographyTokens.detail.monospaced())
            .padding(.horizontal, SpacingTokens.xxxs)
            .background(ColorTokens.accent.opacity(strength == .soft ? 0.12 : 0.26),
                        in: RoundedRectangle(cornerRadius: corners == .square ? 0 : corners == .rounded ? SpacingTokens.nano : SpacingTokens.xs, style: .continuous))
    }
}

/// The Settings window's sidebar.
struct LabSTSidebar: View {
    var selected = "Editor"
    /// With a search in the sidebar (43.5, SE1), only the pages that match.
    var only: [String]?
    static let pages: [(String, String)] = [("General", "gearshape"), ("Notifications", "bell"), ("Appearance", "paintbrush"), ("Editor", "character.cursor.ibeam"),
                                            ("Databases", "cylinder.split.1x2"), ("Sidebar", "sidebar.left"), ("Search", "magnifyingglass"), ("Results", "tablecells"),
                                            ("EchoSense", "sparkles"), ("Diagrams", "point.3.connected.trianglepath.dotted"), ("Keyboard Shortcuts", "command")]
    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
            ForEach(Self.pages.filter { only?.contains($0.0) ?? true }, id: \.0) { page in
                Label(page.0, systemImage: page.1).font(TypographyTokens.standard)
                    .foregroundStyle(page.0 == selected ? ColorTokens.Text.onFill : ColorTokens.Text.primary)
                    .padding(.horizontal, SpacingTokens.xs).frame(maxWidth: .infinity, minHeight: SpacingTokens.lg + SpacingTokens.xxs, alignment: .leading)
                    .background(page.0 == selected ? ColorTokens.accent : .clear, in: .rect(cornerRadius: SpacingTokens.xxs2))
            }
            Spacer()
        }
        .padding(SpacingTokens.xs)
        .frame(width: 180)
        .background(ColorTokens.Background.secondary)
    }
}
