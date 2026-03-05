#if os(macOS)
import AppKit
#endif
import SwiftUI

extension TableStructureEditorView {

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
                    .font(TypographyTokens.label.weight(.semibold))
                    .foregroundStyle(foreground)
                    .padding(.top, subtitle == nil ? 0 : 1)
            }

            VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 2) {
                Text(text)
                    .font(TypographyTokens.label.weight(.semibold))
                    .foregroundStyle(foreground)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let subtitle {
                    Text(subtitle)
                        .font(TypographyTokens.compact)
                        .foregroundStyle(foreground.opacity(0.8))
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
            }
        }
        .padding(.horizontal, SpacingTokens.xs2)
        .padding(.vertical, subtitle == nil ? SpacingTokens.xxs : SpacingTokens.xxs2)
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
            .font(TypographyTokens.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, SpacingTokens.xxs)
            .padding(.vertical, SpacingTokens.xxs2)
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
