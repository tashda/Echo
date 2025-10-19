import SwiftUI

struct ToolbarFlexibleContainer<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
#if os(macOS)
        FlexibleToolbarHost(content: content)
#else
        content
#endif
    }
}

#if os(macOS)
private struct FlexibleToolbarHost<Content: View>: NSViewRepresentable {
    var content: Content

    func makeNSView(context: Context) -> NSHostingView<Content> {
        createHostingView()
    }

    func updateNSView(_ nsView: NSHostingView<Content>, context: Context) {
        nsView.rootView = content
    }

    private func createHostingView() -> NSHostingView<Content> {
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.setContentHuggingPriority(.init(1), for: .horizontal)
        hostingView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        hostingView.setContentHuggingPriority(.defaultLow, for: .vertical)
        hostingView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return hostingView
    }
}
#endif
