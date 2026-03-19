import SwiftUI

/// A standardized form row for macOS 26 (Tahoe) patterns.
/// Consolidates existing SettingsRowWithInfo and manual LabeledContent usage
/// into a single, token-aware component for both Settings and detail views.
public struct PropertyRow<Control: View>: View {
    let title: String
    let subtitle: String?
    let info: String?
    @ViewBuilder let control: () -> Control
    
    @State private var showPopover = false

    public init(
        title: String,
        subtitle: String? = nil,
        info: String? = nil,
        @ViewBuilder control: @escaping () -> Control
    ) {
        self.title = title
        self.subtitle = subtitle
        self.info = info
        self.control = control
    }

    public var body: some View {
        if subtitle != nil {
            // When subtitle is present, use HStack for vertical centering
            HStack(alignment: .center) {
                labelContent
                Spacer()
                controlContent
            }
        } else {
            LabeledContent {
                controlContent
            } label: {
                labelContent
            }
        }
    }

    private var labelContent: some View {
        VStack(alignment: .leading, spacing: LayoutTokens.Form.labelSubtitleSpacing) {
            Text(title)
                .font(TypographyTokens.formLabel)

            if let subtitle {
                Text(subtitle)
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
    }

    @ViewBuilder
    private var controlContent: some View {
        if let info {
            HStack(spacing: SpacingTokens.xs) {
                control()
                infoButton(text: info)
            }
        } else {
            control()
        }
    }

    private func infoButton(text: String) -> some View {
        Button(action: { showPopover.toggle() }) {
            Image(systemName: "info.circle")
                .imageScale(.medium)
        }
        .buttonStyle(.plain)
        .foregroundStyle(ColorTokens.Text.secondary)
        .popover(isPresented: $showPopover, attachmentAnchor: .rect(.bounds), arrowEdge: .trailing) {
            Text(text)
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(SpacingTokens.md)
                .frame(width: LayoutTokens.Form.infoPopoverWidth)
        }
    }
}
