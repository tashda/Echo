import SwiftUI

/// The top of a server card: its name, its version where the style puts it, and the dock.
struct LabSCHeaderView: View {
    let server: LabSCServer
    let state: LabSCState
    let options: LabSCOptions
    let onChoose: (String) -> Void
    let onCustomize: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            switch options.header {
            case .today:
                HStack(alignment: .firstTextBaseline) {
                    Text(server.name).font(SidebarRowConstants.serverHeaderFont).lineLimit(1)
                    Spacer(minLength: SpacingTokens.xxs)
                    Text(server.rawVersion.replacingOccurrences(of: "Microsoft ", with: ""))
                        .font(SidebarRowConstants.trailingFont)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .lineLimit(1)
                }
                .padding(.horizontal, SpacingTokens.sm)
                dock
            case .oneLine:
                HStack(spacing: SpacingTokens.xxs) {
                    title
                    Spacer(minLength: SpacingTokens.xxs)
                    dock
                }
                .padding(.leading, SpacingTokens.sm)
                .padding(.trailing, SpacingTokens.xxs2)
            case .navigator:
                title.padding(.horizontal, SpacingTokens.sm)
                dock
                Divider().padding(.horizontal, SpacingTokens.xs)
            case .segmented, .sectionMenu, .glass, .labelled:
                title.padding(.horizontal, SpacingTokens.sm)
                dock
            }
        }
        .padding(.top, SpacingTokens.sm)
    }

    private var dock: some View {
        LabSCDock(server: server, state: state, options: options, onChoose: onChoose, onCustomize: onCustomize)
    }

    /// The name, with the product and release under it, beside it, or only in the tooltip.
    @ViewBuilder
    private var title: some View {
        let version = options.header == .oneLine ? .tooltip : options.version
        Group {
            switch version {
            case .below:
                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    name
                    Text(server.productLabel)
                        .font(SidebarRowConstants.trailingFont)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .lineLimit(1)
                }
            case .beside:
                HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xxs2) {
                    name
                    Text(server.productLabel)
                        .font(SidebarRowConstants.trailingFont)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .lineLimit(1)
                }
            case .tooltip:
                name
            }
        }
        .help("\(server.name) · \(server.rawVersion)")
    }

    private var name: some View {
        Text(server.name)
            .font(options.density.nameFont)
            .foregroundStyle(ColorTokens.Text.primary)
            .lineLimit(1)
    }
}
