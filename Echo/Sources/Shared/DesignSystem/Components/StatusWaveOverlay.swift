import SwiftUI

/// A soft ambient glow inside a Liquid Glass card, used to signal connection status.
///
/// Two modes:
/// - **One-shot**: Toggle `trigger` to play a single pulse that fades (success/failure).
/// - **Continuous**: Set `continuous = true` for a gentle breathing glow (in-progress).
///
/// The glow fills the card shape and pulses opacity, creating the impression that
/// the glass itself is softly illuminated from within.
struct StatusWaveOverlay: View {
    let color: Color
    let cornerRadius: CGFloat
    var trigger: Bool = false
    var continuous: Bool = false

    @State private var glowIntensity: Double = 0
    @State private var loopTask: Task<Void, Never>?

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        color.opacity(glowIntensity * 0.06),
                        color.opacity(glowIntensity * 0.10),
                        color.opacity(glowIntensity * 0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .allowsHitTesting(false)
            .onChange(of: trigger) { _, _ in
                playOnce()
            }
            .onChange(of: continuous) { _, running in
                if running { startBreathing() } else { stopBreathing() }
            }
            .onAppear {
                if continuous { startBreathing() }
            }
            .onDisappear { stopBreathing() }
    }

    // MARK: - One-Shot Pulse

    private func playOnce() {
        stopBreathing()

        withAnimation(.easeIn(duration: 0.3)) {
            glowIntensity = 1.0
        }

        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(.easeOut(duration: 1.0)) {
                glowIntensity = 0
            }
        }
    }

    // MARK: - Continuous Breathing

    private func startBreathing() {
        stopBreathing()
        glowIntensity = 0

        loopTask = Task {
            // Initial fade in
            withAnimation(.easeIn(duration: 0.6)) {
                glowIntensity = 1.0
            }
            try? await Task.sleep(nanoseconds: 600_000_000)

            // Breathing loop
            while !Task.isCancelled {
                withAnimation(.easeInOut(duration: 1.6)) {
                    glowIntensity = 0.3
                }
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                guard !Task.isCancelled else { return }

                withAnimation(.easeInOut(duration: 1.6)) {
                    glowIntensity = 1.0
                }
                try? await Task.sleep(nanoseconds: 1_600_000_000)
            }
        }
    }

    private func stopBreathing() {
        loopTask?.cancel()
        loopTask = nil
        withAnimation(.easeOut(duration: 0.4)) {
            glowIntensity = 0
        }
    }
}
