import SwiftUI

/// An area's Spec view: an outline of parts and elements, the live specimen with numbered
/// hotspots, and the selected element's properties.
struct SpecView: View {
    let area: LabArea
    let spec: AreaSpec

    @State private var selected: String?
    @State private var showsIDs = true
    @State private var stageSettings = LabStageSettings()
    @State private var search = ""

    var body: some View {
        HStack(spacing: 0) {
            SpecOutline(spec: spec, selected: $selected, search: $search)
                .frame(width: 230)
            Divider()
            stageColumn
            Divider()
            SpecInspector(area: area, spec: spec, selected: selected)
                .frame(width: 300)
        }
    }

    private var stageColumn: some View {
        VStack(spacing: SpacingTokens.sm) {
            HStack {
                Toggle("Show IDs", isOn: $showsIDs)
                Spacer()
            }
            .controlSize(.small)
            LabStageControlBar(settings: stageSettings)
            spec.specimen()
                .labStage(stageSettings)
                .frame(maxWidth: .infinity)
                .frame(height: spec.stageHeight)
                .background(ColorTokens.Workspace.canvas)
                .overlayPreferenceValue(SpecAnchorKey.self) { anchors in
                    GeometryReader { proxy in
                        let placed = placements(anchors, proxy)
                        ForEach(placed, id: \.number) { item in
                            SpecHotspot(id: spec.id(item.number), isSelected: selected == item.number, showsBadge: showsIDs || selected == item.number)
                                .position(item.badge)
                                .onTapGesture { selected = item.number }
                            if selected == item.number {
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(Color.red, lineWidth: 1.5)
                                    .frame(width: item.rect.width + 4, height: item.rect.height + 4)
                                    .position(x: item.rect.midX, y: item.rect.midY)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                }
                .clipShape(.rect(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(ColorTokens.Workspace.cardEdge.opacity(0.5), lineWidth: 0.5))
                .preferredColorScheme(stageSettings.appearance.scheme)
            if let controls = spec.controls {
                controls().controlSize(.small).frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("Click a badge on the specimen, or a row in the outline, to see that element's properties.")
                .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
            Spacer(minLength: 0)
        }
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity)
    }
}

/// Where each element's badge goes. Badges start at their element's top-left corner and step
/// aside when they would cover another badge, so every ID stays readable.
private struct SpecPlacement {
    let number: String
    let rect: CGRect
    let badge: CGPoint
}

private func placements(_ anchors: [String: Anchor<CGRect>], _ proxy: GeometryProxy) -> [SpecPlacement] {
    let size = CGSize(width: 32, height: 14)
    var taken: [CGRect] = []
    var result: [SpecPlacement] = []
    let order = anchors.keys.sorted { $0.compare($1, options: .numeric) == .orderedAscending }
    for number in order {
        guard let anchor = anchors[number] else { continue }
        let rect = proxy[anchor]
        // Above the element, never on top of it; when that spot is taken, slide right, then up.
        func origin(column: Int, row: Int) -> CGPoint {
            CGPoint(x: min(max(rect.minX + CGFloat(column) * (size.width + 2), 0), max(proxy.size.width - size.width, 0)),
                    y: max(rect.minY - size.height - 3 - CGFloat(row) * (size.height + 2), 0))
        }
        var frame = CGRect(origin: origin(column: 0, row: 0), size: size)
        var step = 0
        while taken.contains(where: { $0.insetBy(dx: -1, dy: -1).intersects(frame) }), step < 40 {
            step += 1
            frame = CGRect(origin: origin(column: step % 8, row: step / 8), size: size)
        }
        taken.append(frame)
        result.append(SpecPlacement(number: number, rect: rect, badge: CGPoint(x: frame.midX, y: frame.midY)))
    }
    return result
}

private struct SpecHotspot: View {
    let id: String
    let isSelected: Bool
    let showsBadge: Bool

    var body: some View {
        Text(id.split(separator: "-").last.map(String.init) ?? id)
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white)
            .frame(width: 32, height: 14)
            .background(isSelected ? Color.red : Color.accentColor, in: Capsule())
            .opacity(showsBadge ? 1 : 0)
            .contentShape(Capsule())
    }
}

/// Parts and elements, with a field that jumps to an ID or a name.
private struct SpecOutline: View {
    let spec: AreaSpec
    @Binding var selected: String?
    @Binding var search: String

    var body: some View {
        VStack(spacing: 0) {
            TextField("", text: $search, prompt: Text("Go to ID or name, e.g. 2.7 or close"))
                .textFieldStyle(.roundedBorder).controlSize(.small)
                .padding(SpacingTokens.xs)
                .onSubmit { if let first = matches.first { selected = first } }
            List(selection: $selected) {
                ForEach(spec.parts) { part in
                    let elements = part.elements.filter { matches(part, $0) }
                    if !elements.isEmpty || search.isEmpty {
                        Section {
                            ForEach(elements) { element in
                                HStack(spacing: 6) {
                                    Text(element.number).font(.system(size: 11, design: .monospaced)).foregroundStyle(ColorTokens.Text.tertiary)
                                        .frame(width: 34, alignment: .leading)
                                    Text(element.name).strikethrough(element.isRetired)
                                }
                                .tag(element.number)
                            }
                        } header: {
                            Text("\(spec.code)-\(part.number) · \(part.name)")
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }

    private func matches(_ part: SpecPart, _ element: SpecElement) -> Bool {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        return query.isEmpty || element.number.hasPrefix(query) || element.name.lowercased().contains(query)
            || "\(spec.code)-\(element.number)".lowercased().contains(query)
    }

    private var matches: [String] {
        spec.parts.flatMap { part in part.elements.filter { matches(part, $0) }.map(\.number) }
    }
}

/// The selected element's properties, and the way to give feedback on it.
private struct SpecInspector: View {
    let area: LabArea
    let spec: AreaSpec
    let selected: String?
    @Environment(\.labGiveFeedback) private var giveFeedback
    @Environment(\.labOpenRound) private var openRound

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                if let selected, let element = spec.element(number: selected) {
                    header(element)
                    ForEach(element.groups) { group in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(group.title.uppercased()).font(.system(size: 10, weight: .semibold)).foregroundStyle(ColorTokens.Text.tertiary)
                            ForEach(group.rows) { row in
                                VStack(alignment: .leading, spacing: 0) {
                                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                                        Text(row.label).foregroundStyle(ColorTokens.Text.secondary)
                                        Spacer(minLength: 4)
                                        if let swatch = row.swatch {
                                            RoundedRectangle(cornerRadius: 3).fill(swatch).frame(width: 16, height: 12)
                                                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.secondary.opacity(0.4), lineWidth: 0.5))
                                        }
                                        Text(row.value).multilineTextAlignment(.trailing).textSelection(.enabled)
                                    }
                                    if let token = row.token {
                                        Text(token).font(.system(size: 10, design: .monospaced)).foregroundStyle(ColorTokens.Text.tertiary)
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                    }
                                }
                                .font(TypographyTokens.standard)
                            }
                        }
                    }
                    if !element.rounds.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ROUNDS").font(.system(size: 10, weight: .semibold)).foregroundStyle(ColorTokens.Text.tertiary)
                            ForEach(element.rounds, id: \.self) { id in
                                if let page = LabRegistry.page(id: id) {
                                    Button(page.title) { openRound(id) }.buttonStyle(.link).font(TypographyTokens.detail)
                                }
                            }
                        }
                    }
                    if !element.files.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CODE").font(.system(size: 10, weight: .semibold)).foregroundStyle(ColorTokens.Text.tertiary)
                            ForEach(element.files, id: \.self) { Text($0).font(.system(size: 10, design: .monospaced)).textSelection(.enabled) }
                        }
                    }
                    Button("Feedback on \(spec.id(element.number))") { giveFeedback(spec.id(element.number), element.name) }
                        .buttonStyle(.borderedProminent).controlSize(.small)
                } else {
                    ContentUnavailableView("Pick an element", systemImage: "cursorarrow.click",
                                           description: Text("Click a numbered badge on the specimen, or a row in the outline."))
                }
            }
            .padding(SpacingTokens.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(ColorTokens.Surface.rest)
    }

    private func header(_ element: SpecElement) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(spec.id(element.number)).font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundStyle(ColorTokens.accent)
            Text(element.name).font(TypographyTokens.title3.weight(.semibold))
            Text(element.summary).font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if element.isRetired { Text("Retired: no longer in Echo").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.warning) }
        }
    }
}
