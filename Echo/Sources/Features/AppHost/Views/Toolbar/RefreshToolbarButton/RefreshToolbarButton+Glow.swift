import SwiftUI

struct GlowBorder: View {
    var cornerRadius: CGFloat
    var color: Color

    @State private var gradientRotation: Angle = .degrees(0)

    private var animatedGradient: AngularGradient {
        let colors = [
            color,
            color.opacity(0.75),
            color.opacity(0.45),
            color.opacity(0.75),
            color
        ]
        return AngularGradient(gradient: Gradient(colors: colors), center: .center, angle: gradientRotation)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(animatedGradient, lineWidth: 4)
                .blur(radius: 7)
                .opacity(0.4)
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(animatedGradient, lineWidth: 10)
                .blur(radius: 16)
                .opacity(0.24)
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(animatedGradient, lineWidth: 18)
                .blur(radius: 26)
                .opacity(0.18)
        }
        .animation(.linear(duration: 3.0).repeatForever(autoreverses: false), value: gradientRotation)
        .onAppear {
            gradientRotation = .degrees(360)
        }
    }
}
