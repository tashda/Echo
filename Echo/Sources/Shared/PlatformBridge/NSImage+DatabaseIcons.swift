import AppKit

extension DatabaseType {
    func rasterSymbolImage(
        canvasSize: CGFloat,
        glyphSize: CGFloat
    ) -> NSImage? {
        guard let image = NSImage(named: iconName) else { return nil }

        let targetSize = NSSize(width: canvasSize, height: canvasSize)
        let canvas = NSImage(size: targetSize, flipped: false) { rect in
            let sourceSize = image.size
            guard sourceSize.width > 0, sourceSize.height > 0 else { return false }

            let scale = min(glyphSize / sourceSize.width, glyphSize / sourceSize.height)
            let drawSize = NSSize(
                width: sourceSize.width * scale,
                height: sourceSize.height * scale
            )
            let drawRect = NSRect(
                x: rect.midX - drawSize.width / 2,
                y: rect.midY - drawSize.height / 2,
                width: drawSize.width,
                height: drawSize.height
            )

            image.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }

        canvas.isTemplate = usesTemplateIcon
        return canvas
    }

    func menuIconImage(
        canvasSize: CGFloat = LayoutTokens.Icon.menuCanvas,
        glyphSize: CGFloat = LayoutTokens.Icon.menuGlyph
    ) -> NSImage? {
        rasterSymbolImage(canvasSize: canvasSize, glyphSize: glyphSize)
    }

    func formControlIconImage() -> NSImage? {
        rasterSymbolImage(
            canvasSize: LayoutTokens.Icon.formControlCanvas,
            glyphSize: LayoutTokens.Icon.formControlGlyph
        )
    }
}
