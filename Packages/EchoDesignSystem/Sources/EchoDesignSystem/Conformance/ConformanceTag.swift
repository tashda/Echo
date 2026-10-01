import SwiftUI

extension View {
    /// Names this part of a view for conformance captures: its frame and timeline are recorded
    /// under `name`, and Echo's part is compared with the accepted round's part of the same name.
    /// Without a capture running it does nothing.
    public func conformanceTag(_ name: String) -> some View {
        modifier(ConformanceTagModifier(name: name))
    }
}

private struct ConformanceTagModifier: ViewModifier {
    let name: String

    @Environment(\.conformanceRecorder) private var recorder

    func body(content: Content) -> some View {
        if let recorder {
            content
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .named(ConformanceRecorder.space))
                } action: { frame in
                    recorder.record(name, frame: frame)
                }
                .onAppear { recorder.appeared(name) }
                .onDisappear { recorder.disappeared(name) }
        } else {
            content
        }
    }
}
