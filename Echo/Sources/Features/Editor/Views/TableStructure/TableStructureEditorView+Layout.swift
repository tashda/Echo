#if os(macOS)
import AppKit
#endif
import SwiftUI

extension TableStructureEditorView {
    
    internal var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(viewModel.schemaName).\(viewModel.tableName)")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(headerPrimaryColor)
                    Label(tab.connection.connectionName, systemImage: "externaldrive.connected.to.line.below")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(headerSecondaryColor)
                        .labelStyle(.titleAndIcon)
                }

                Spacer(minLength: 16)

                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(accentColor)
                }
            }

            TableStructureTitleView(
                selection: $selectedSection,
                accentColor: accentColor
            )
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(headerBackgroundColor)
        .overlay(
            Rectangle()
                .fill(headerBorderColor)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    internal var content: some View {
        ZStack(alignment: .bottomLeading) {
            ScrollView {
                LazyVStack(alignment: .center, spacing: 20) {
                    if let message = viewModel.lastError {
                        statusMessage(text: message, systemImage: "exclamationmark.triangle.fill", tint: .red)
                    } else if let success = viewModel.lastSuccessMessage {
                        statusMessage(text: success, systemImage: "checkmark.circle.fill", tint: .green)
                    }

                    switch selectedSection {
                    case .columns:
                        columnsSection
                        primaryKeySection
                        uniqueConstraintsSection
                    case .indexes:
                        indexesSection
                    case .relations:
                        foreignKeysSection
                        dependenciesSection
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 140)
            }

            bottomActionBar
                .padding(.horizontal, 32)
                .padding(.bottom, 28)
        }
    }

    private var bottomActionBar: some View {
        HStack(spacing: 16) {
            reloadButton
            applyButton
            Spacer()
        }
    }

    internal func statusMessage(text: String, systemImage: String, tint: Color) -> some View {
        Label {
            Text(text)
                .font(.system(size: 12, weight: .medium))
        } icon: {
            Image(systemName: systemImage)
                .symbolRenderingMode(.palette)
                .foregroundStyle(tint, tint.opacity(0.4))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(tint.opacity(0.3), lineWidth: 1)
                )
        )
        .frame(maxWidth: 580, alignment: .center)
    }

    private var reloadButton: some View {
        Button {
            Task { await viewModel.reload() }
        } label: {
            HStack(spacing: 10) {
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                }

                Text(viewModel.isLoading ? "Reloading…" : "Reload")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .fill(accentColor.opacity(viewModel.isLoading ? 0.18 : 0.1))
                    )
            )
            .overlay(
                Capsule()
                    .stroke(accentColor.opacity(viewModel.isLoading ? 0.65 : 0.35), lineWidth: 1)
            )
            .foregroundColor(accentColor)
            .shadow(color: Color.black.opacity(0.12), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isApplying)
        .opacity(viewModel.isApplying ? 0.55 : 1)
        .animation(.easeInOut(duration: 0.25), value: viewModel.isLoading)
        .animation(.easeInOut(duration: 0.25), value: viewModel.isApplying)
        .help("Reload table structure")
    }

    private var applyButton: some View {
        let isActive = viewModel.hasPendingChanges || viewModel.isApplying
        let isEnabled = viewModel.hasPendingChanges && !viewModel.isApplying

        return Button(action: applyChanges) {
            HStack(spacing: 10) {
                if viewModel.isApplying {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(applyActiveForegroundColor)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                }

                Text(viewModel.isApplying ? "Applying…" : "Apply")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .background {
                ZStack {
                    Capsule()
                        .fill(.ultraThinMaterial)
                    if isActive {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        accentColor.opacity(0.9),
                                        accentColor.opacity(0.7)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            }
            .overlay(
                Capsule()
                    .stroke(
                        isActive ? accentColor.opacity(0.75) : Color.white.opacity(0.2),
                        lineWidth: isActive ? 1.4 : 1
                    )
            )
            .foregroundColor(isActive ? applyActiveForegroundColor : Color.secondary)
            .shadow(color: isActive ? accentColor.opacity(0.4) : Color.black.opacity(0.08), radius: isActive ? 18 : 8, y: isActive ? 10 : 4)
            .scaleEffect(isActive ? 1.04 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: viewModel.hasPendingChanges)
        .animation(.easeInOut(duration: 0.25), value: viewModel.isApplying)
        .keyboardShortcut(.return, modifiers: [.command, .shift])
        .help(isEnabled ? "Apply pending changes (⇧⌘⏎)" : "No changes to apply")
    }

    #if os(macOS)
    internal var accentNSColor: NSColor {
        if projectStore.globalSettings.useServerColorAsAccent {
            return NSColor(tab.connection.color)
        }
        return NSColor.controlAccentColor
    }

    internal var accentColor: Color { Color(nsColor: accentNSColor) }

    internal var applyActiveForegroundColor: Color {
        let workingColor = accentNSColor.usingColorSpace(.extendedSRGB) ?? accentNSColor
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        workingColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return luminance > 0.6 ? Color.black.opacity(0.85) : Color.white
    }
    #else
    internal var accentColor: Color {
        projectStore.globalSettings.useServerColorAsAccent ? tab.connection.color : .accentColor
    }

    internal var applyActiveForegroundColor: Color {
        guard let cgColor = accentColor.cgColor,
              let srgbSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let converted = cgColor.converted(to: srgbSpace, intent: .defaultIntent, options: nil),
              let components = converted.components else {
            return .white
        }

        let componentCount = converted.numberOfComponents
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat

        if componentCount >= 3 {
            red = components[0]
            green = components[1]
            blue = components[2]
        } else {
            red = components[0]
            green = components[0]
            blue = components[0]
        }

        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return luminance > 0.6 ? Color.black.opacity(0.85) : Color.white
    }
    #endif

    internal var inlineButtonBackground: Color {
        ColorTokens.Background.secondary.opacity(0.2)
    }

    internal var headerBackgroundColor: Color {
        ColorTokens.Background.secondary
    }

    internal var headerBorderColor: Color {
        ColorTokens.Text.primary.opacity(themeManager.effectiveColorScheme == .dark ? 0.35 : 0.12)
    }

    internal var headerPrimaryColor: Color {
        ColorTokens.Text.primary
    }

    internal var headerSecondaryColor: Color {
        ColorTokens.Text.primary.opacity(themeManager.effectiveColorScheme == .dark ? 0.7 : 0.55)
    }

    internal func sectionCard<Content: View>(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        action: SectionAction? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let action {
                    sectionActionButton(action)
                }
            }

            content()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 12, y: 4)
        .frame(maxWidth: 580, alignment: .center)
    }

    @ViewBuilder
    private func sectionActionButton(_ action: SectionAction) -> some View {
        if action.style == .accent {
            Button(action: action.action) {
                sectionActionLabel(for: action)
            }
            .labelStyle(.titleAndIcon)
            .controlSize(.small)
            .buttonStyle(.borderedProminent)
            .tint(accentColor)
        } else {
            Button(action: action.action) {
                sectionActionLabel(for: action)
            }
            .labelStyle(.titleAndIcon)
            .controlSize(.small)
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private func sectionActionLabel(for action: SectionAction) -> some View {
        if let systemImage = action.systemImage {
            Label(action.title, systemImage: systemImage)
        } else {
            Text(action.title)
        }
    }

    internal func cardRowBackground(isNew: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(nsColor: .textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(isNew ? 0.35 : 0.2), lineWidth: 0.8)
            )
    }

    internal func bubbleLabel(
        _ text: String,
        systemImage: String? = nil,
        tint: Color = Color(nsColor: .unemphasizedSelectedTextBackgroundColor),
        foreground: Color = .secondary,
        subtitle: String? = nil
    ) -> some View {
        HStack(alignment: subtitle == nil ? .center : .top, spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(foreground)
                    .padding(.top, subtitle == nil ? 0 : 1)
            }

            VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 2) {
                Text(text)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(foreground)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundStyle(foreground.opacity(0.8))
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, subtitle == nil ? 4 : 6)
        .background(
            Capsule()
                .fill(tint)
        )
        .overlay(
            Capsule()
                .stroke(Color(nsColor: .separatorColor).opacity(0.18))
        )
        .fixedSize(horizontal: false, vertical: true)
    }

    internal func placeholderText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
    }

    internal struct TableStructureTitleView: View {
        @Binding var selection: TableStructureSection
        let accentColor: Color

        var body: some View {
            HStack {
                Spacer()

                Picker("", selection: $selection) {
                    ForEach(TableStructureSection.allCases) { section in
                        Text(section.displayName)
                            .tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .tint(accentColor)
                .controlSize(.regular)
                .frame(maxWidth: 340)

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    internal struct SectionAction {
        enum Style {
            case plain
            case accent
        }

        let title: String
        let systemImage: String?
        let style: Style
        let action: () -> Void

        init(title: String, systemImage: String? = nil, style: Style = .plain, action: @escaping () -> Void) {
            self.title = title
            self.systemImage = systemImage
            self.style = style
            self.action = action
        }
    }
}
