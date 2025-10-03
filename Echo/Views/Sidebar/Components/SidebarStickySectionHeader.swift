import SwiftUI

struct SidebarStickySectionHeader: View {
    let title: String
    var count: Int? = nil
    var isExpanded: Bool = true
    let coordinateSpaceName: String
    var onTap: (() -> Void)? = nil

    @State private var isPinned = false

    var body: some View {
        let cornerRadius: CGFloat = isPinned && isExpanded ? 10 : 4

        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            if let count {
                Text("\(count)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.8))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.06), in: Capsule())
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            if isPinned && isExpanded {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.85))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                Color.clear
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            if isPinned && isExpanded {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            }
        }
        .shadow(color: (isPinned && isExpanded) ? .black.opacity(0.15) : .clear, radius: 20, x: 0, y: 8)
        .shadow(color: (isPinned && isExpanded) ? .black.opacity(0.05) : .clear, radius: 2, x: 0, y: 1)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
        .background(
            GeometryReader { proxy in
                let minY = proxy.frame(in: .named(coordinateSpaceName)).minY
                DispatchQueue.main.async {
                    let pinned = minY <= 0.5
                    if pinned != isPinned {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isPinned = pinned
                        }
                    }
                }
                return Color.clear
            }
        )
    }
}
