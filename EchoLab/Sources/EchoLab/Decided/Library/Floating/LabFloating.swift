import SwiftUI

struct LabToast: Identifiable, Equatable {
    let id = UUID()
    let symbol: String
    let tint: Color
    let title: String
    let detail: String
    var count = 1
}

/// Toasts that stack and melt together, expand on hover, and a toolbar bell whose history card
/// grows out of the button. All in one glass container, so they morph into each other.
struct LabFloatingPlayground: View {
    @State private var toasts: [LabToast] = []
    @State private var expandedToast: UUID?
    @State private var showsHistory = false
    @State private var speed: LabSpeed = .standard
    @Namespace private var glass

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let samples: [LabToast] = [
        LabToast(symbol: "checkmark.circle.fill", tint: .green, title: "Connected to tippr", detail: "10.0.4.21 · PostgreSQL 16.4"),
        LabToast(symbol: "exclamationmark.triangle.fill", tint: .red, title: "Connection to pg16-lab failed", detail: "could not connect to server: Connection refused. Is the server running on host 10.0.4.30 and accepting TCP/IP connections on port 5432?"),
        LabToast(symbol: "tray.and.arrow.down.fill", tint: .blue, title: "Export finished", detail: "salary.csv · 1.2 M rows · 84 MB"),
    ]

    var body: some View {
        LabStage(title: "Floating glass · toasts and notification history") {
            Button("Post notification") { post() }
            Button("Post the same one again") { repeatLast() }.disabled(toasts.isEmpty)
            LabPicker(title: "Speed", selection: $speed, options: LabSpeed.allCases)
        } content: {
            ZStack(alignment: .topTrailing) {
                Color(nsColor: .windowBackgroundColor)
                LabCard { LabEditorText() }
                    .padding(EdgeInsets(top: 56, leading: 16, bottom: 16, trailing: 16))

                GlassEffectContainer(spacing: 14) {
                    VStack(alignment: .trailing, spacing: 8) {
                        bell
                        if showsHistory { historyCard }
                        ForEach(toasts) { toast in toastView(toast) }
                    }
                }
                .padding(12)
            }
        }
        .frame(minWidth: 760, minHeight: 540)
    }

    private var animation: Animation { speed.spring(reduceMotion: reduceMotion) }

    // MARK: Bell and history

    private var bell: some View {
        Button {
            withAnimation(animation) { showsHistory.toggle() }
        } label: {
            Image(systemName: showsHistory ? "bell.fill" : "bell")
                .font(.system(size: 13))
                .frame(width: 30, height: 30)
                .overlay(alignment: .topTrailing) {
                    if !toasts.isEmpty && !showsHistory {
                        Circle().fill(.red).frame(width: 7, height: 7).offset(x: -5, y: 5)
                    }
                }
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .glassEffectID("bell", in: glass)
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Notifications").font(.headline)
                Spacer()
                Text("Clear").font(.callout).foregroundStyle(Color.accentColor)
            }
            HStack(spacing: 6) {
                ForEach(["All", "Errors", "Connection", "Jobs"], id: \.self) { filter in
                    Text(filter)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(filter == "All" ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.06), in: Capsule())
                }
            }
            ForEach(samples) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: item.symbol).foregroundStyle(item.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.system(size: 12, weight: .semibold))
                        Text(item.detail).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: 10))
            }
        }
        .padding(12)
        .frame(width: 320)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
        .glassEffectID("history", in: glass)
        .glassEffectTransition(.matchedGeometry)
    }

    // MARK: Toasts

    private func toastView(_ toast: LabToast) -> some View {
        let isExpanded = expandedToast == toast.id
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: toast.symbol).foregroundStyle(toast.tint)
                Text(toast.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                if toast.count > 1 {
                    Text("×\(toast.count)").font(.system(size: 11, weight: .semibold)).monospacedDigit().foregroundStyle(.secondary)
                }
            }
            if isExpanded {
                Text(toast.detail).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button("Retry") {}.buttonStyle(.glass)
                    Button("Details") {}.buttonStyle(.glass)
                    Spacer()
                    Button { dismiss(toast) } label: { Image(systemName: "xmark") }.buttonStyle(.plain).foregroundStyle(.secondary)
                }
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(width: isExpanded ? 320 : nil, alignment: .leading)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: isExpanded ? 16 : 20))
        .glassEffectID(toast.id, in: glass)
        .onHover { inside in
            withAnimation(animation) { expandedToast = inside ? toast.id : (expandedToast == toast.id ? nil : expandedToast) }
        }
    }

    private func post() {
        let next = samples[toasts.count % samples.count]
        withAnimation(animation) {
            toasts.insert(LabToast(symbol: next.symbol, tint: next.tint, title: next.title, detail: next.detail), at: 0)
            if toasts.count > 3 { toasts.removeLast() }
        }
        scheduleDismiss(toasts[0])
    }

    private func repeatLast() {
        guard !toasts.isEmpty else { return }
        withAnimation(animation) { toasts[0].count += 1 }
    }

    private func scheduleDismiss(_ toast: LabToast) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(toast.tint == .red ? 8 : 4))
            // Hovered toasts stay until the pointer leaves.
            while expandedToast == toast.id { try? await Task.sleep(for: .milliseconds(300)) }
            dismiss(toast)
        }
    }

    private func dismiss(_ toast: LabToast) {
        withAnimation(animation) {
            toasts.removeAll { $0.id == toast.id }
            if expandedToast == toast.id { expandedToast = nil }
        }
    }
}

#Preview("Floating glass · toasts, notification history") {
    LabFloatingPlayground()
}
