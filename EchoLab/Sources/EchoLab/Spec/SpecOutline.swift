import SwiftUI

/// Every area, part and element, with a field that jumps to an ID or a name.
struct SpecOutline: View {
    @Bindable var state: LabSpecState
    @Binding var search: String
    @State private var hovered: String?

    private var query: String { search.trimmingCharacters(in: .whitespaces).lowercased() }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(ColorTokens.Text.tertiary)
                TextField("", text: $search, prompt: Text("Find an ID or name"))
                    .textFieldStyle(.plain)
                    .onSubmit { if let first = firstMatch { state.select(first) } }
                if !search.isEmpty {
                    Button("Clear", systemImage: "xmark.circle.fill") { search = "" }
                        .labelStyle(.iconOnly).buttonStyle(.plain).foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .padding(.horizontal, SpacingTokens.xs).frame(height: 28)
            .background(ColorTokens.Surface.hover, in: .rect(cornerRadius: 8, style: .continuous))
            .padding(SpacingTokens.xs)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(LabAreas.all) { area in
                        if matches(area) { areaBlock(area) }
                    }
                }
                .padding(.horizontal, SpacingTokens.xs).padding(.bottom, SpacingTokens.sm)
            }
        }
        .background(ColorTokens.Background.secondary.opacity(0.5))
    }

    // MARK: Areas

    private func matches(_ area: LabArea) -> Bool {
        query.isEmpty || area.title.lowercased().contains(query) || (area.spec?.parts.flatMap(\.elements).contains { elementMatches($0, area) } ?? false)
    }

    private func elementMatches(_ element: SpecElement, _ area: LabArea) -> Bool {
        query.isEmpty || element.number.hasPrefix(query) || element.name.lowercased().contains(query)
            || "\(area.spec?.code ?? "")-\(element.number)".lowercased().contains(query)
    }

    private func isOpen(_ area: LabArea) -> Bool { !query.isEmpty || state.expandedAreas.contains(area.id) }

    @ViewBuilder
    private func areaBlock(_ area: LabArea) -> some View {
        let open = isOpen(area)
        Button {
            if state.expandedAreas.contains(area.id) { state.expandedAreas.remove(area.id) } else { state.expandedAreas.insert(area.id) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)).rotationEffect(.degrees(open ? 90 : 0))
                    .foregroundStyle(ColorTokens.Text.tertiary).frame(width: 10)
                Image(systemName: area.symbol).foregroundStyle(ColorTokens.accent).frame(width: 18)
                Text(area.title).fontWeight(.semibold)
                Spacer()
                if let spec = area.spec {
                    Text("\(spec.parts.flatMap(\.elements).count)").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .padding(.horizontal, 6).frame(height: 28).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        if open {
            if let spec = area.spec {
                ForEach(spec.parts) { part in
                    let elements = part.elements.filter { elementMatches($0, area) }
                    if !elements.isEmpty {
                        Text("\(spec.code)-\(part.number) · \(part.name)")
                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(ColorTokens.Text.tertiary)
                            .padding(.leading, 34).padding(.top, 6).padding(.bottom, 1)
                        ForEach(elements) { element in
                            row(id: spec.id(element.number), number: element.number, name: element.name,
                                retired: element.isRetired, hasStates: !element.states.isEmpty)
                        }
                    }
                }
            } else {
                row(id: "area:\(area.id)", number: "", name: "Overview", retired: false, hasStates: false, note: "not numbered yet")
            }
        }
    }

    private func row(id: String, number: String, name: String, retired: Bool, hasStates: Bool, note: String? = nil) -> some View {
        let isSelected = state.selected == id
        return Button { state.select(id) } label: {
            HStack(spacing: 6) {
                Text(number).font(.system(size: 11, design: .monospaced)).foregroundStyle(ColorTokens.Text.tertiary)
                    .frame(width: 34, alignment: .trailing)
                Text(name).strikethrough(retired).foregroundStyle(retired ? ColorTokens.Text.tertiary : ColorTokens.Text.primary)
                Spacer(minLength: 4)
                if hasStates { Image(systemName: "eye").font(.system(size: 9)).foregroundStyle(ColorTokens.Text.tertiary) }
                if let note { Text(note).font(.system(size: 10)).foregroundStyle(ColorTokens.Text.tertiary) }
            }
            .font(TypographyTokens.standard)
            .padding(.horizontal, 6).frame(height: 24)
            .background(isSelected ? ColorTokens.Sidebar.selectedFill : (hovered == id ? ColorTokens.Sidebar.hoverFill : .clear),
                        in: .rect(cornerRadius: 6, style: .continuous))
            .padding(.leading, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 ? id : (hovered == id ? nil : hovered) }
    }

    private var firstMatch: String? {
        for area in LabAreas.all {
            if let spec = area.spec {
                for element in spec.parts.flatMap(\.elements) where elementMatches(element, area) { return spec.id(element.number) }
            }
        }
        return nil
    }
}
