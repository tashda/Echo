import SwiftUI

/// "server › database" pinned above the Explorer once the server's own header has scrolled out
/// of view. Plain text on a soft blur, with no fill of its own; two actions appear on hover.
struct ExplorerPinnedPathBar: View {
    let serverName: String
    let databaseName: String?
    let onScrollToServer: () -> Void
    let onScrollToDatabase: () -> Void
    let onCollapseOtherDatabases: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: SpacingTokens.xxs) {
            Button(action: onScrollToServer) {
                Text(serverName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ColorTokens.Text.primary)
                    .lineLimit(1)
                    .fixedSize()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Scroll to \(serverName)")

            if let databaseName {
                Text("›")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.Text.tertiary)

                Button(action: onScrollToDatabase) {
                    Text(databaseName)
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .contentTransition(.opacity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Scroll to \(databaseName)")
            }

            Spacer(minLength: SpacingTokens.xs)

            HStack(spacing: SpacingTokens.xxxs) {
                actionButton("arrow.up.to.line", help: "Top of Server", action: onScrollToServer)
                if databaseName != nil {
                    actionButton(
                        "rectangle.compress.vertical",
                        help: "Collapse Other Databases",
                        action: onCollapseOtherDatabases
                    )
                }
            }
            .opacity(isHovering ? 1 : 0)
            .allowsHitTesting(isHovering)
        }
        .padding(.leading, SpacingTokens.sm)
        .padding(.trailing, SpacingTokens.xs)
        .frame(height: LayoutTokens.PinnedPath.height)
        .background(alignment: .top) { blur }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.18), value: isHovering)
        .animation(.easeInOut(duration: 0.22), value: databaseName)
    }

    /// Material that fades out downward, so rows dissolve under the text instead of meeting an edge.
    private var blur: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.55),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: LayoutTokens.PinnedPath.height + LayoutTokens.PinnedPath.fadeExtent)
            .allowsHitTesting(false)
    }

    private func actionButton(_ systemImage: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ColorTokens.Text.secondary)
                .frame(width: 22, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}
