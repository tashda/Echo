import SwiftUI

/// A round page laid out from a `RoundSpec` as a workbench: controls (with presets) on the left,
/// the exhibits in the middle where they stay put and wrap to the width, and the decision in the
/// right-hand panel. Every part scrolls on its own, so you never lose the previews while you
/// change a control. A round with only a few controls gets a slim bar above the exhibits instead.
/// Specimens are drawn at the toolbar zoom (100% is the size Echo draws them): the exhibits wrap
/// into as many columns as fit at that size, or show one at a time to flip between them.
struct LabRoundPage: View {
    let pageID: String
    let spec: RoundSpec

    /// How the exhibits are laid out, the same for every round.
    enum Layout: String {
        case sideBySide, oneAtATime
    }

    @State private var values: RoundValues
    @State private var settings = LabStageSettings.shared
    @State private var canvasWidth: CGFloat = 0
    @AppStorage("lab.round.showsControls") private var showsControls = true
    @AppStorage("lab.round.layout") private var layout = Layout.sideBySide
    /// The exhibit shown on its own, per round.
    @AppStorage private var aloneID: String

    init(pageID: String, spec: RoundSpec) {
        self.pageID = pageID
        self.spec = spec
        _values = State(initialValue: RoundValues.shared(pageID: pageID, controls: spec.controls))
        _aloneID = AppStorage(wrappedValue: spec.exhibits.first?.id ?? "", "lab.round.alone.\(pageID)")
    }

    private var page: LabPage { LabRegistry.page(id: pageID) ?? LabRegistry.pages[0] }
    private var usesColumn: Bool { spec.controls.count > 4 || !spec.presets.isEmpty || !spec.actions.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LabRoundInfoBox(page: page, hint: true).padding([.horizontal, .top], SpacingTokens.md).padding(.bottom, SpacingTokens.xs)
            HStack(alignment: .top, spacing: 0) {
                if usesColumn && showsControls {
                    RoundControlsColumn(page: page, spec: spec, values: values, settings: settings).frame(width: 290)
                    Divider()
                }
                canvas
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var showsAlone: Bool { layout == .oneAtATime && spec.exhibits.count > 1 }
    private var aloneExhibit: RoundSpec.Exhibit? { spec.exhibits.first { $0.id == aloneID } ?? spec.exhibits.first }

    private func card(_ exhibit: RoundSpec.Exhibit) -> some View {
        RoundExhibitCard(page: page, exhibit: exhibit, values: values, settings: settings, decides: spec.exhibitTopic != nil,
                         recommendation: spec.exhibitTopic.flatMap { $0.recommended == exhibit.id ? $0.why : nil },
                         isAlone: showsAlone,
                         toggleAlone: spec.exhibits.count > 1 ? {
                             aloneID = exhibit.id
                             layout = showsAlone ? .sideBySide : .oneAtATime
                         } : nil)
    }

    /// As many columns as fit with the widest specimen at the zoom; one when even that does not fit.
    private var columns: [GridItem] {
        let chrome = (SpacingTokens.sm + SpacingTokens.xs) * 2
        let cardWidth = (spec.exhibits.map(\.designWidth).max() ?? 320) * CGFloat(LabZoom.shared.level) + chrome
        let fitting = Int((canvasWidth + SpacingTokens.sm) / (cardWidth + SpacingTokens.sm))
        let count = min(max(fitting, 1), max(spec.exhibits.count, 1))
        return Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sm, alignment: .top), count: count)
    }

    private var canvas: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if usesColumn {
                    Button { showsControls.toggle() } label: {
                        Label(showsControls ? "Hide controls" : "Show controls", systemImage: "slider.horizontal.3")
                    }
                    .buttonStyle(LabPillButtonStyle(isOn: showsControls))
                }
                Label("Try it", systemImage: "hand.tap").font(TypographyTokens.headline)
                Spacer()
                if spec.exhibits.count > 1 {
                    Picker("Layout", selection: $layout) {
                        Text("Side by Side").tag(Layout.sideBySide)
                        Text("One at a Time").tag(Layout.oneAtATime)
                    }
                    .pickerStyle(.segmented).labelsHidden().fixedSize().controlSize(.small)
                    .help("Side by side fits as many exhibits as the zoom allows; one at a time shows one exhibit at a time, as large as the zoom asks")
                }
            }
            .padding(.horizontal, SpacingTokens.md).padding(.vertical, SpacingTokens.xs)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    if !usesColumn { RoundControlsBar(page: page, spec: spec, values: values, settings: settings) }
                    if showsAlone, let exhibit = aloneExhibit {
                        RoundExhibitStrip(page: page, spec: spec, selection: $aloneID)
                        card(exhibit)
                    } else {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: SpacingTokens.sm) {
                            ForEach(spec.exhibits) { card($0) }
                        }
                    }
                }
                .padding(SpacingTokens.md)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.width - SpacingTokens.md * 2 }) { canvasWidth = $0 }
            }
        }
        .labScrollSizing()
    }
}
