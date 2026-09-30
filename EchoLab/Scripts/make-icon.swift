import AppKit

// Builds Echo Labs' icon: Echo's app icon with LABS written across the lower part.
// Usage: swift Scripts/make-icon.swift   (run from EchoLab/)
let source = "../Echo/Assets.xcassets/AppIcon.appiconset/Echo-mac-1024.png"
guard let base = NSImage(contentsOfFile: source) else { fatalError("Echo icon not found") }
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
base.draw(in: NSRect(origin: .zero, size: size))

let font = NSFont.systemFont(ofSize: 150, weight: .heavy)
let rounded = font.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 150) } ?? font
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.55)
shadow.shadowBlurRadius = 24
shadow.shadowOffset = NSSize(width: 0, height: -6)
let attributes: [NSAttributedString.Key: Any] = [
    .font: rounded,
    .foregroundColor: NSColor.white.withAlphaComponent(0.96),
    .kern: 26,
    .shadow: shadow,
]
let text = NSAttributedString(string: "LABS", attributes: attributes)
let textSize = text.size()
text.draw(at: NSPoint(x: (size.width - textSize.width + 26) / 2, y: 168))
image.unlockFocus()

let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "Resources/EchoLab-1024.png"))

// Build the .icns from the 1024 master.
let iconset = "Resources/EchoLab.iconset"
try? FileManager.default.removeItem(atPath: iconset)
try! FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)
for (points, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    let pixels = points * scale
    let out = NSImage(size: NSSize(width: pixels, height: pixels))
    out.lockFocus()
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    out.unlockFocus()
    let r = NSBitmapImageRep(data: out.tiffRepresentation!)!
    let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
    try! r.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(iconset)/\(name)"))
}
