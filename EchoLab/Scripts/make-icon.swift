import AppKit

// Builds Echo Labs' icon from the Acid master (Design/AppIcon/EchoIcon-Labs.svg, made by
// Design/AppIcon/build_icon.py): the same three rows on a darker tile in lab colours.
// Usage: swift Scripts/make-icon.swift   (run from EchoLab/)
let source = "../Design/AppIcon/EchoIcon-Labs.png"
guard let image = NSImage(contentsOfFile: source) else { fatalError("Labs icon master not found; run Design/AppIcon/build_icon.py") }
let size = NSSize(width: 1024, height: 1024)
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
