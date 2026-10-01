import SwiftUI

/// The whole design documentation on one page: an outline of every area, part and element, the
/// live specimen with numbered hotspots, and the selected element's properties.
struct LabSpecPage: View {
    @State private var state = LabSpecState.shared
    @State private var search = ""
    @State private var showsIDs = LabPrefs.load("spec.showIDsGlobal", default: true)
    @State private var stageSettings = LabStageSettings.shared
    @AppStorage("lab.spec.showsOutline") private var showsOutline = true

    private var selection: (area: LabArea, spec: AreaSpec, element: SpecElement)? { state.element(forSelection: state.selected) }

    var body: some View {
        HStack(spacing: 0) {
            if showsOutline {
                SpecOutline(state: state, search: $search).frame(width: 250)
                Divider()
            }
            center
            Divider()
            SpecInspector(state: state).frame(width: 320)
        }
        .onAppear { if state.selected == nil { state.select("TABS-2.4") } else { state.apply() } }
    }

    @ViewBuilder
    private var center: some View {
        if let area = state.area(forSelection: state.selected) {
            if let found = selection {
                stageColumn(found.area, found.spec, found.element)
            } else {
                AsBuiltView(area: area, page: area.asBuilt)
            }
        } else {
            ContentUnavailableView("Pick something to look at", systemImage: "list.bullet.rectangle",
                                   description: Text("Choose an element in the outline."))
        }
    }

    private func stageColumn(_ area: LabArea, _ spec: AreaSpec, _ element: SpecElement) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            HStack(spacing: SpacingTokens.xs) {
                Button(showsOutline ? "Hide outline" : "Show outline", systemImage: "sidebar.left") { showsOutline.toggle() }
                    .labelStyle(.iconOnly).buttonStyle(.borderless)
                Text(area.title).foregroundStyle(ColorTokens.Text.secondary)
                Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(ColorTokens.Text.tertiary)
                Text(spec.part(number: String(element.number.split(separator: ".").first ?? ""))?.name ?? "")
                    .foregroundStyle(ColorTokens.Text.secondary)
                Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(ColorTokens.Text.tertiary)
                Text(element.name).fontWeight(.semibold)
                Spacer()
                Button("Previous", systemImage: "chevron.up") { step(-1) }.labelStyle(.iconOnly).buttonStyle(.borderless)
                Button("Next", systemImage: "chevron.down") { step(1) }.labelStyle(.iconOnly).buttonStyle(.borderless)
            }
            .font(TypographyTokens.standard)
            HStack {
                Toggle("Show IDs", isOn: Binding(get: { showsIDs }, set: { showsIDs = $0; LabPrefs.save($0, key: "spec.showIDsGlobal") }))
                    .controlSize(.small)
                Spacer()
            }
            LabStageControlBar(settings: stageSettings)
            ZStack(alignment: .topTrailing) {
                spec.specimen()
                    .labStage(stageSettings)
                    .frame(maxWidth: .infinity)
                    .frame(height: spec.stageHeight)
                    .background(ColorTokens.Workspace.canvas)
                    .overlayPreferenceValue(SpecAnchorKey.self) { anchors in hotspots(anchors, spec: spec) }
                    .clipShape(.rect(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(ColorTokens.Workspace.cardEdge.opacity(0.5), lineWidth: 0.5))
                    .preferredColorScheme(stageSettings.appearance.scheme)
                if let key = state.previewState, let name = element.states.first(where: { $0.key == key })?.name {
                    HStack(spacing: 6) {
                        Image(systemName: "eye")
                        Text("Previewing: \(name)")
                        Button("Release") { state.setPreview(nil) }.buttonStyle(.link)
                    }
                    .font(TypographyTokens.detail)
                    .padding(.horizontal, SpacingTokens.xs).padding(.vertical, 3)
                    .background(.regularMaterial, in: Capsule())
                    .padding(SpacingTokens.xs)
                }
            }
            if let controls = spec.controls {
                controls().controlSize(.small).frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
        }
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity)
    }

    private func hotspots(_ anchors: [String: Anchor<CGRect>], spec: AreaSpec) -> some View {
        GeometryReader { proxy in
            let placed = SpecPlacements.compute(anchors, proxy)
            ForEach(placed, id: \.number) { item in
                let full = spec.id(item.number)
                let isSelected = state.selected == full
                SpecHotspot(label: item.number, isSelected: isSelected, showsBadge: showsIDs || isSelected)
                    .position(item.badge)
                    .onTapGesture { state.select(full) }
                if isSelected {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.red, lineWidth: 1.5)
                        .frame(width: item.rect.width + 4, height: item.rect.height + 4)
                        .position(x: item.rect.midX, y: item.rect.midY)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    /// Steps to the previous or next element inside the same area.
    private func step(_ delta: Int) {
        guard let found = selection else { return }
        let all = found.spec.parts.flatMap(\.elements)
        guard let index = all.firstIndex(where: { $0.number == found.element.number }) else { return }
        let next = all[(index + delta + all.count) % all.count]
        state.select(found.spec.id(next.number))
    }
}
