// axdump <pid> [maxDepth] [windowIndex]: the accessibility tree of an app's window as indented lines,
// with each element's role, title or description, value and frame (screen points), so a script can
// click it. Needs the Accessibility permission for the terminal that runs it.
import ApplicationServices
import Foundation

func whole(_ value: CGFloat) -> Int { value.isFinite ? Int(max(min(value, 1e9), -1e9)) : 0 }

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}

/// Position and size, relative to the window (or sheet) the element is in: `[x,y wxh @cx,cy]`, where cx,cy is
/// the centre, which is what a `click` step takes.
func frame(_ element: AXUIElement, origin: CGPoint) -> (text: String, position: CGPoint) {
    var point = CGPoint.zero, size = CGSize.zero
    guard let p = attribute(element, kAXPositionAttribute), CFGetTypeID(p) == AXValueGetTypeID(), AXValueGetValue(p as! AXValue, .cgPoint, &point),
          let s = attribute(element, kAXSizeAttribute), CFGetTypeID(s) == AXValueGetTypeID(), AXValueGetValue(s as! AXValue, .cgSize, &size)
    else { return ("", .zero) }
    let x = whole(point.x - origin.x), y = whole(point.y - origin.y)
    return ("[\(x),\(y) \(whole(size.width))x\(whole(size.height)) @\(x + whole(size.width) / 2),\(y + whole(size.height) / 2)]", point)
}

func text(_ element: AXUIElement) -> String {
    ["AXTitle", "AXDescription", "AXValue", "AXHelp", "AXIdentifier"].compactMap { name -> String? in
        guard let value = attribute(element, name) else { return nil }
        let string = (value as? String) ?? ((value as? NSNumber).map { "\($0)" } ?? "")
        return string.isEmpty ? nil : "\(name.dropFirst(2))='\(string.prefix(60))'"
    }.joined(separator: " ")
}

func dump(_ element: AXUIElement, depth: Int, maxDepth: Int, origin: CGPoint) {
    guard depth <= maxDepth else { return }
    let role = (attribute(element, "AXRole") as? String ?? "?").dropFirst(2)
    var here = origin
    let box = frame(element, origin: origin)
    // A window or sheet starts its own coordinates.
    if role == "Window" || role == "Sheet" { here = box.position }
    let shown = role == "Window" || role == "Sheet" ? frame(element, origin: box.position).text : box.text
    print("\(String(repeating: " ", count: depth))\(role) \(text(element)) \(shown)")
    // AXSKIP=id1,id2 leaves out what is inside elements with those identifiers (a long list, say).
    let skipped = (ProcessInfo.processInfo.environment["AXSKIP"] ?? "").split(separator: ",").map(String.init)
    if let identifier = attribute(element, "AXIdentifier") as? String, skipped.contains(identifier) { return }
    // A long table or list is shown by its first rows (AXROWS, default 4): every cell is a round trip to the app.
    var children = (attribute(element, "AXChildren") as? [AXUIElement]) ?? []
    if ["Outline", "Table", "List"].contains(String(role)) { children = Array(children.prefix(Int(ProcessInfo.processInfo.environment["AXROWS"] ?? "") ?? 4)) }
    for child in children { dump(child, depth: depth + 1, maxDepth: maxDepth, origin: here) }
}

let arguments = CommandLine.arguments
guard arguments.count > 1, let pid = Int32(arguments[1]) else { print("usage: axdump <pid> [maxDepth] [windowIndex]"); exit(1) }
let application = AXUIElementCreateApplication(pid)
// The first request switches the app's accessibility tree on; ask again until it answers.
var windows = (attribute(application, "AXWindows") as? [AXUIElement]) ?? []
for _ in 0..<10 where windows.isEmpty {
    Thread.sleep(forTimeInterval: 0.5)
    windows = (attribute(application, "AXWindows") as? [AXUIElement]) ?? []
}
let index = arguments.count > 3 ? Int(arguments[3]) ?? 0 : 0
guard windows.indices.contains(index) else { print("no window \(index) of \(windows.count)"); exit(1) }
dump(windows[index], depth: 0, maxDepth: arguments.count > 2 ? Int(arguments[2]) ?? 30 : 30, origin: .zero)
