import SwiftUI

/// The top of a server card: its name, its version where the style puts it, and the dock. With
/// Pinned › Icons only, the name and the dock are drawn apart so only the dock stays pinned.
struct LabSCHeaderView: View {
    enum Part { case all, name, dock }

    let server: LabSCServer
    let state: LabSCState
    let options: LabSCOptions
    var part: Part = .all
    let onChoose: @MainActor (String) -> Void
    let onCustomize: () -> Void

    /// One line and today's header can't be split; they pin whole.
    static func canSplit(_ header: LabSCHeader) -> Bool { header != .oneLine && header != .today }
    private var isSplittable: Bool { Self.canSplit(options.header) }
    private var showsName: Bool { part != .dock || !isSplittable }
    private var showsDock: Bool { part != .name }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            switch options.header {
            case .today:
                if showsName {
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
                }
            case .oneLine:
                if showsName {
                    HStack(spacing: SpacingTokens.xxs) {
                        title
                        Spacer(minLength: SpacingTokens.xxs)
                        dock
                    }
                    .padding(.leading, SpacingTokens.sm)
                    .padding(.trailing, SpacingTokens.xxs2)
                }
            case .navigator:
                if showsName { title.padding(.horizontal, SpacingTokens.sm) }
                if showsDock {
                    dock
                    Divider().padding(.horizontal, SpacingTokens.xs)
                }
            case .segmented, .sectionMenu, .glass, .labelled:
                if showsName { title.padding(.horizontal, SpacingTokens.sm) }
                if showsDock { dock }
            }
        }
        .padding(.top, part == .dock && isSplittable ? SpacingTokens.xxs : SpacingTokens.sm)
    }

    private var dock: some View {
        LabSCDock(server: server, state: state, options: options, onChoose: onChoose, onCustomize: onCustomize)
    }

    /// I5: while the chosen section loads, a spinner sits beside the server's name.
    private var isLoadingSection: Bool {
        options.initialLoad == .headerSpinner
            && state.loading.contains(state.sectionKey(server, state.chosenSection(of: server)))
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
                    productLabel
                }
            case .beside:
                HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xxs2) {
                    name
                    productLabel
                }
            case .tooltip:
                name
            }
        }
        .help("\(server.name) · \(server.rawVersion)")
    }

    private var name: some View {
        HStack(spacing: SpacingTokens.xxs2) {
            Text(server.name)
                .font(options.density.nameFont)
                .foregroundStyle(ColorTokens.Text.primary)
                .lineLimit(1)
            if isLoadingSection {
                ProgressView().controlSize(.mini).transition(.opacity)
            }
        }
    }

    private var productLabel: some View {
        Text(server.productLabel)
            .font(SidebarRowConstants.trailingFont)
            .foregroundStyle(ColorTokens.Text.tertiary)
            .lineLimit(1)
    }
}
