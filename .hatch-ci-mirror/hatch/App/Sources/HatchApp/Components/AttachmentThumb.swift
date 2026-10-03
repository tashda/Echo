import SwiftUI
import AppKit
import HatchCore

/// A screenshot attached to a ticket. The path is relative to the Hatch folder unless it starts with "/".
struct AttachmentThumb: View {
    @EnvironmentObject var state: AppState
    let attachment: Attachment
    var size: CGFloat = 96

    private var url: URL {
        if attachment.path.hasPrefix("/") { return URL(fileURLWithPath: attachment.path) }
        return state.paths.root.appendingPathComponent(attachment.path)
    }

    var body: some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            thumbnail
        }
        .buttonStyle(.plain)
        .help(attachment.caption ?? attachment.path)
    }

    @ViewBuilder private var thumbnail: some View {
        if let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.12))
                .frame(width: size, height: size)
                .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
        }
    }
}
