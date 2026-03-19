import SwiftUI
import EchoSense

/// A visually rich connection header for the sidebar matching macOS 26 Tahoe aesthetics.
///
/// Displays connection icon, name, and detailed host/type metadata in a Liquid Glass card.
struct SidebarConnectionHeader: View {
    let connectionName: String
    let subtitle: String
    let databaseType: DatabaseType
    let connectionColor: Color
    let isExpanded: Binding<Bool>
    let isColorful: Bool
    let isSecure: Bool
    let connectionState: ConnectionState
    let onAction: () -> Void
    var trailingAccessory: TrailingAccessory = .chevron

    @State private var isHovered = false
    @State private var currentWidth: CGFloat = 0

    enum TrailingAccessory {
        case chevron
        case spinner
        case retryButton(() -> Void)
        case none
    }

    private var statusInfo: (color: Color, label: String?) {
        switch connectionState {
        case .connected:
            return (Color.green, "Online")
        case .connecting, .testing:
            return (Color.orange, "Connecting")
        case .disconnected:
            return (Color.gray, "Disconnected")
        case .error:
            return (Color.red, "Failed")
        }
    }

    var body: some View {
        Button(action: onAction) {
            HStack(spacing: SpacingTokens.sm) {
                // Native SF Symbol (standalone, no background card)
                let iconColor = isColorful ? connectionColor : ColorTokens.Text.secondary

                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: databaseType.symbolName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(iconColor.gradient)
                        .frame(width: 24, height: 24)

                    // Small status dot overlaid on icon
                    Circle()
                        .fill(statusInfo.color)
                        .frame(width: 7, height: 7)
                        .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
                        .offset(x: 2, y: 2)
                }

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: SpacingTokens.xxs) {
                        Text(connectionName)
                            .font(TypographyTokens.standard.weight(.semibold))
                            .foregroundStyle(ColorTokens.Text.primary)
                            .lineLimit(1)

                        if isSecure {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(ColorTokens.Text.tertiary)
                        }
                    }

                    HStack(spacing: SpacingTokens.xxs) {
                        Text(subtitle)
                            .font(TypographyTokens.compact)
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .lineLimit(1)

                        if case .error = connectionState {
                            Text("\u{2022}")
                            Text("Error")
                                .font(TypographyTokens.compact)
                                .foregroundStyle(ColorTokens.Status.error)
                        }
                    }
                }

                Spacer()

                trailingAccessoryView
            }
            .padding(.vertical, SpacingTokens.sm)
            .padding(.horizontal, SpacingTokens.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(
                .regular
                .tint(isColorful ? connectionColor.opacity(0.01) : nil)
                .interactive(true),
                in: RoundedRectangle(cornerRadius: SidebarRowConstants.hoverCornerRadius, style: .continuous)
            )
            .background {
                if isColorful {
                    // Whisper-thin mesh tint for the glass
                    RoundedRectangle(cornerRadius: SidebarRowConstants.hoverCornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [connectionColor.opacity(0.02), connectionColor.opacity(0.005)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: SidebarRowConstants.hoverCornerRadius, style: .continuous))
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { currentWidth = geo.size.width }
                        .onChange(of: geo.size.width) { _, newValue in currentWidth = newValue }
                }
            )
        }
        .buttonStyle(.plain)
        .padding(.bottom, SpacingTokens.xxs)
        // Combined ID forces an instant layout re-pass when width OR state changes
        .id("\(connectionName)-\(currentWidth)-\(isExpanded.wrappedValue)")
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
        }
    }

    @ViewBuilder
    private var trailingAccessoryView: some View {
        switch trailingAccessory {
        case .chevron:
            Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(ColorTokens.Text.quaternary)
                .padding(.trailing, SpacingTokens.xxs)
        case .spinner:
            ProgressView()
                .controlSize(.small)
                .padding(.trailing, SpacingTokens.xxs)
        case .retryButton(let action):
            Button {
                action()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .buttonStyle(.plain)
            .help("Retry connection")
            .padding(.trailing, SpacingTokens.xxs)
        case .none:
            EmptyView()
        }
    }
}
