import SwiftUI

struct TintedIcon: View {
    let systemImage: String
    var tint: Color = .accentColor
    var size: CGFloat = 18
    var boxSize: CGFloat = 32
    var cornerRadius: CGFloat = 8
    var backgroundOpacity: Double = 0.12

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: boxSize, height: boxSize)
            .background(
                tint.opacity(backgroundOpacity),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
    }
}
