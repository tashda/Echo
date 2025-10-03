import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// A transparent, cross-platform view that handles both tap (with modifier keys)
/// and drag gestures, correcting for limitations in pure SwiftUI.
struct PointerGestureArea: View {
    var onTap: (EventModifiers) -> Void
    var onDrag: (CGSize) -> Void
    var onDragEnd: () -> Void

    var body: some View {
#if os(iOS) || os(visionOS)
        // On iPadOS/iOS, we use a UIViewRepresentable to host a UIPanGestureRecognizer,
        // which can correctly report modifier flags.
        UIKitGestureRecognizerRepresentable(onTap: onTap, onDrag: onDrag, onDragEnd: onDragEnd)
#elseif os(macOS)
        // On macOS, we can use a DragGesture and poll NSEvent for modifiers.
        macOSGestureArea
#else
        // Provide a fallback for other platforms that might not support this interaction.
        Color.clear
#endif
    }

#if os(macOS)
    @State private var initialDragTranslation: CGSize? = nil

    private var macOSGestureArea: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        // Capture the initial translation to differentiate tap from drag
                        if initialDragTranslation == nil {
                            initialDragTranslation = value.translation
                        }
                        onDrag(value.translation)
                    }
                    .onEnded { value in
                        let travelDistance = hypot(value.translation.width, value.translation.height)
                        if travelDistance < 5 { // Treat as a tap
                            var modifiers: EventModifiers = []
                            let flags = NSEvent.modifierFlags
                            if flags.contains(.command) { modifiers.insert(.command) }
                            if flags.contains(.shift) { modifiers.insert(.shift) }
                            if flags.contains(.option) { modifiers.insert(.option) }
                            if flags.contains(.control) { modifiers.insert(.control) }
                            onTap(modifiers)
                        }
                        onDragEnd()
                        initialDragTranslation = nil
                    }
            )
    }
#endif
}

#if os(iOS) || os(visionOS)
private struct UIKitGestureRecognizerRepresentable: UIViewRepresentable {
    var onTap: (EventModifiers) -> Void
    var onDrag: (CGSize) -> Void
    var onDragEnd: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let gesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan))
        gesture.minimumNumberOfTouches = 1
        gesture.maximumNumberOfTouches = 1
        view.addGestureRecognizer(gesture)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject {
        var parent: UIKitGestureRecognizerRepresentable
        private var hasDragged = false

        init(parent: UIKitGestureRecognizerRepresentable) {
            self.parent = parent
        }

        @objc func handlePan(gesture: UIPanGestureRecognizer) {
            switch gesture.state {
            case .began:
                hasDragged = false
            case .changed:
                // Only register as a drag if movement is significant
                let translation = gesture.translation(in: gesture.view)
                if !hasDragged && hypot(translation.x, translation.y) > 5.0 {
                    hasDragged = true
                }
                if hasDragged {
                    parent.onDrag(CGSize(width: translation.x, height: translation.y))
                }
            case .ended, .cancelled:
                if !hasDragged {
                    parent.onTap(gesture.modifierFlags.toSwiftUI())
                }
                parent.onDragEnd()
                hasDragged = false
            default:
                break
            }
        }
    }
}

private extension UIKeyModifierFlags {
    func toSwiftUI() -> EventModifiers {
        var result: EventModifiers = []
        if contains(.shift) { result.insert(.shift) }
        if contains(.control) { result.insert(.control) }
        if contains(.alternate) { result.insert(.option) }
        if contains(.command) { result.insert(.command) }
        if contains(.alphaShift) { result.insert(.capsLock) }
        return result
    }
}
#endif
