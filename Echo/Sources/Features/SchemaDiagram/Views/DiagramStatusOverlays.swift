import SwiftUI

struct DiagramBlockingStatusCard: View {
    let icon: String?
    let tint: Color
    let title: String
    let message: String
    let palette: DiagramPalette

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            VStack(spacing: 16) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(tint)
                } else {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .frame(width: 240)
                        .tint(tint)
                }
                VStack(spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(palette.headerTitle)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(palette.headerSubtitle)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(palette.overlayBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(palette.overlayBorder, lineWidth: 1)
                    )
            )
            .shadow(color: palette.nodeShadow.opacity(0.7), radius: 18, x: 0, y: 12)
        }
    }
}

struct DiagramBannerStatus: View {
    let message: String
    let showsProgress: Bool
    let palette: DiagramPalette

    var body: some View {
        VStack {
            HStack {
                if showsProgress {
                    ProgressView()
                        .controlSize(.small)
                        .tint(palette.accent)
                } else {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.accent)
                }
                Text(message)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.headerTitle)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(palette.overlayBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(palette.overlayBorder, lineWidth: 1)
                    )
            )
            .shadow(color: palette.nodeShadow.opacity(0.4), radius: 12, x: 0, y: 6)
            .padding(.top, 16)
            .padding(.horizontal, 24)

            Spacer()
        }
        .allowsHitTesting(false)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.2), value: showsProgress)
    }
}
