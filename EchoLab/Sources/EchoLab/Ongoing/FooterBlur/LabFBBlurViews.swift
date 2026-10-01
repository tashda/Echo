import AppKit
import CoreImage

/// Round 44: the AppKit blurs, each a real blur of the rows under it. They sit in the grid's clip
/// view, as Echo's do, because a background filter only sees its superview's content.

/// One step of a stacked blur: a Gaussian blur of what is under it (the rows and the steps before
/// it), shown where its mask is opaque.
final class LabFBStepView: NSView {
    private let maskLayer = CALayer()

    init(radius: CGFloat) {
        super.init(frame: .zero)
        wantsLayer = true
        layerUsesCoreImageFilters = true
        if let blur = CIFilter(name: "CIGaussianBlur") {
            blur.setDefaults()
            blur.setValue(radius, forKey: kCIInputRadiusKey)
            backgroundFilters = [blur]
        }
        maskLayer.contentsGravity = .resize
        layer?.mask = maskLayer
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func setMask(_ image: CGImage?) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        maskLayer.contents = image
        maskLayer.frame = bounds
        CATransaction.commit()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        maskLayer.frame = bounds
        CATransaction.commit()
    }
}

/// One blur whose radius follows a mask, from Core Image's public `CIMaskedVariableBlur`.
/// Its mask is made for the strip's size in pixels each time it changes: an endless mask stops the
/// window drawing at all.
final class LabFBMaskedBlurView: NSView {
    private var radius: CGFloat = 0
    private var amount: (CGFloat) -> CGFloat = { _ in 0 }
    private var builtSize: NSSize = .zero

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layerUsesCoreImageFilters = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func configure(radius: CGFloat, amount: @escaping (CGFloat) -> CGFloat) {
        self.radius = radius
        self.amount = amount
        builtSize = .zero
        rebuild()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        rebuild()
    }

    private func rebuild() {
        guard bounds.size != builtSize, bounds.width > 0, bounds.height > 0,
              let blur = CIFilter(name: "CIMaskedVariableBlur") else { return }
        builtSize = bounds.size
        // A background filter's image is in points here, with its origin at the strip's bottom.
        let size = bounds.size
        let mask = LabFBMaskImage.strip(width: size.width, height: size.height, amount: amount)?
            .cropped(to: CGRect(origin: .zero, size: size))
        blur.setDefaults()
        blur.setValue(radius, forKey: kCIInputRadiusKey)
        blur.setValue(mask, forKey: "inputMask")
        backgroundFilters = [blur]
    }
}
