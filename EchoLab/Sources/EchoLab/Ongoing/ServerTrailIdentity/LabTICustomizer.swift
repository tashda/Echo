import SwiftUI

/// What the user would see to make a server's trail item their own: a live preview among its
/// neighbours, and the options the customisation level allows.
struct LabTICustomizer: View {
    let look: LabTILook
    @State private var custom = LabTICustomisation()
    private let swatches: [Color] = [ColorTokens.Status.error, ColorTokens.Status.warning, Color.yellow, ColorTokens.Status.success,
                                     Color.teal, ColorTokens.Status.info, Color.indigo, Color.purple, Color.pink, Color.gray]
    private let symbols = ["cylinder.fill", "bolt.fill", "flame.fill", "leaf.fill", "shield.fill", "star.fill",
                           "moon.fill", "cloud.fill", "hammer.fill", "flag.fill", "gearshape.fill", "building.2.fill"]
    private let emoji = ["🐘", "🐬", "🚀", "🔥", "🧪", "🏭", "🎯", "🌍"]
    private let server = LabTIServer.named("tippr")

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            preview
            if look.custom == .automatic {
                Text("Nothing to customise: the letters come from the name and the colour from the connection. Two servers named prod-eu-pg01 and prod-eu-pg02 are both \"PR\".")
                    .font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                options
            }
            Spacer(minLength: SpacingTokens.none)
        }
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ColorTokens.Workspace.canvas)
    }

    /// The server among others, in the rail, and large.
    private var preview: some View {
        HStack(spacing: SpacingTokens.lg) {
            VStack(spacing: LayoutTokens.Rail.itemSpacing) {
                neighbour("prod")
                LabTIMark(server: server, style: look.style, custom: custom, isSelected: true)
                neighbour("norway")
                neighbour("pgservices")
            }
            .padding(LayoutTokens.Rail.pillPadding)
            .glassEffect(.regular, in: .capsule)
            VStack(spacing: SpacingTokens.xxs) {
                LabTIMark(server: server, style: look.style, custom: custom, isSelected: true, size: SpacingTokens.xxl + SpacingTokens.lg)
                Text(server.server.name).font(TypographyTokens.standard.weight(.semibold)).foregroundStyle(ColorTokens.Text.primary)
                Text(server.server.product).font(SidebarRowConstants.trailingFont).foregroundStyle(ColorTokens.Text.tertiary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func neighbour(_ id: String) -> some View {
        LabTIMark(server: .named(id), style: look.style)
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            if look.custom.showsColour {
                section("Color") {
                    HStack(spacing: SpacingTokens.xxs2) {
                        ForEach(swatches.indices, id: \.self) { index in
                            Circle().fill(swatches[index]).frame(width: SpacingTokens.md1, height: SpacingTokens.md1)
                                .overlay { if custom.color == swatches[index] { Circle().strokeBorder(ColorTokens.Text.primary, lineWidth: 1.5).padding(-SpacingTokens.xxxs) } }
                                .onTapGesture { custom.color = swatches[index] }
                        }
                    }
                }
            }
            if look.custom.showsGlyph {
                section("Symbol or emoji") {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(SpacingTokens.lg + SpacingTokens.xxs), spacing: SpacingTokens.xxs), count: 10),
                              alignment: .leading, spacing: SpacingTokens.xxs) {
                        ForEach(symbols, id: \.self) { name in
                            glyphButton(.symbol(name)) { Image(systemName: name).font(TypographyTokens.standard) }
                        }
                        ForEach(emoji, id: \.self) { value in
                            glyphButton(.emoji(value)) { Text(value).font(TypographyTokens.prominent) }
                        }
                    }
                }
            }
            if look.custom.showsText {
                section("Letters") {
                    TextField("", text: Binding(get: { custom.text }, set: { custom.text = String($0.prefix(2)) }), prompt: Text("e.g. TP"))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: SpacingTokens.xxxl)
                }
            }
            if look.custom.showsShape {
                section("Shape") {
                    Picker("", selection: Binding(get: { custom.shape ?? .circle }, set: { custom.shape = $0 })) {
                        ForEach(LabTIShape.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: SpacingTokens.xxxl * 3)
                }
            }
            Button("Reset to Automatic") { custom = LabTICustomisation() }
                .buttonStyle(.link)
                .font(TypographyTokens.detail)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            Text(title).font(SidebarRowConstants.sectionHeadingFont).foregroundStyle(ColorTokens.Text.secondary)
            content()
        }
    }

    private func glyphButton<Label: View>(_ glyph: LabTIGlyph, @ViewBuilder label: () -> Label) -> some View {
        label()
            .frame(width: SpacingTokens.lg + SpacingTokens.xxs, height: SpacingTokens.lg + SpacingTokens.xxs)
            .background(custom.glyph == glyph ? ColorTokens.accent.opacity(0.2) : ColorTokens.Text.primary.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: SpacingTokens.xxs2, style: .continuous))
            .onTapGesture { custom.glyph = glyph }
    }
}

/// Nine servers in the trail at once, to judge how the style scales (Echo's own list has twelve).
struct LabTINineServers: View {
    let look: LabTILook

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.lg) {
            VStack(spacing: LayoutTokens.Rail.itemSpacing) {
                ForEach(Array(LabTIServer.all.enumerated()), id: \.offset) { index, server in
                    LabTIMark(server: server, style: look.style, isSelected: index == 2)
                }
            }
            .padding(LayoutTokens.Rail.pillPadding)
            .glassEffect(.regular, in: .capsule)
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                Text("Find tippr, norway and postgres_services. How long did each take?")
                    .font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(LabTIServer.all) { server in
                    HStack(spacing: SpacingTokens.xs) {
                        Circle().fill(server.server.color).frame(width: SpacingTokens.xs, height: SpacingTokens.xs)
                        Text(server.server.name).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                    }
                }
            }
            Spacer(minLength: SpacingTokens.none)
        }
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ColorTokens.Workspace.canvas)
    }
}
