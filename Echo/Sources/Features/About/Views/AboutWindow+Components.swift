import AppKit
import SwiftUI

extension AboutWindow {
    func dependencyDetailCard(for dependency: AboutDependency) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack(alignment: .top, spacing: SpacingTokens.sm) {
                Image(systemName: "doc.badge.gearshape")
                    .font(TypographyTokens.displayLarge.weight(.semibold))
                    .foregroundStyle(ColorTokens.accent)
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    Text(dependency.name)
                        .font(TypographyTokens.title3.weight(.semibold))
                    Text(dependency.purpose)
                        .font(TypographyTokens.body)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                AboutKeyValueRow(title: "License", value: dependency.licenseName, systemImage: "checkmark.seal")
                AboutKeyValueRow(title: "Repository", value: dependency.repositoryURL.absoluteString, systemImage: "link")
                    .textSelection(.enabled)
                Text(dependency.notice)
                    .font(TypographyTokens.footnote)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            HStack(spacing: SpacingTokens.sm) {
                Link(destination: dependency.repositoryURL) {
                    Label("Open Repository", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.borderedProminent)

                if let licenseURL = dependency.licenseURL {
                    Link(destination: licenseURL) {
                        Label("Open License", systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(SpacingTokens.xl)
        .background(AboutCardBackground())
    }
}

struct AboutHeroCard: View {
    let versionString: String
    let buildNumber: String

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.lg) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 8)

            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                Text("Echo")
                    .font(TypographyTokens.title.weight(.bold))
                Text("A native macOS workspace for serious database work.")
                    .font(TypographyTokens.body)
                    .foregroundStyle(ColorTokens.Text.secondary)
                HStack(spacing: SpacingTokens.sm) {
                    AboutPill(text: "Version \(versionString)", systemImage: "tag")
                    AboutPill(text: "Build \(buildNumber)", systemImage: "hammer")
                    AboutPill(text: "macOS", systemImage: "laptopcomputer")
                }
                Link(destination: AboutMetadata.homepageURL) {
                    Label("Visit echodb.dev", systemImage: "globe")
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .padding(SpacingTokens.xl)
        .background(AboutCardBackground())
    }
}

struct AboutLinkCard: View {
    let link: AboutLink

    var body: some View {
        Link(destination: link.url) {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                Label(link.title, systemImage: link.systemImage)
                    .font(TypographyTokens.headline)
                    .foregroundStyle(ColorTokens.Text.primary)
                Text(link.subtitle)
                    .font(TypographyTokens.footnote)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Label("Open", systemImage: "arrow.up.right")
                    .font(TypographyTokens.footnote.weight(.medium))
                    .foregroundStyle(ColorTokens.accent)
            }
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
            .padding(SpacingTokens.md)
            .background(AboutCardBackground())
        }
        .buttonStyle(.plain)
    }
}

struct AboutKeyValueRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.sm) {
            Label(title, systemImage: systemImage)
                .font(TypographyTokens.standard.weight(.medium))
                .foregroundStyle(ColorTokens.Text.primary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct AboutPill: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(TypographyTokens.footnote.weight(.medium))
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.vertical, SpacingTokens.xs)
            .background(
                Capsule(style: .continuous)
                    .fill(ColorTokens.Surface.selected)
            )
    }
}

struct AboutCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(ColorTokens.Background.secondary)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(ColorTokens.Separator.primary.opacity(0.6), lineWidth: 1)
            )
    }
}

struct AboutWindowConfigurator: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        Task { @MainActor in
            guard let window = view.window else { return }
            context.coordinator.configure(window: window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        Task { @MainActor in
            guard let window = nsView.window else { return }
            context.coordinator.configure(window: window)
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        func configure(window: NSWindow) {
            window.identifier = NSUserInterfaceItemIdentifier("about-window")
            window.title = "About Echo"
            window.isExcludedFromWindowsMenu = false
            window.tabbingMode = .disallowed
            window.titlebarSeparatorStyle = .none
            window.appearance = NSAppearance(
                named: AppearanceStore.shared.effectiveColorScheme == .dark ? .darkAqua : .aqua
            )
        }
    }
}
