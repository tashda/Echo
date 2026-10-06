// winlist <owner>: the on-screen windows of an app, "id x y w h name", for `screencapture -l <id>`.
import CoreGraphics
import Foundation
let owner = CommandLine.arguments.dropFirst().first ?? "Echo"
let list = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]) ?? []
for w in list where (w[kCGWindowOwnerName as String] as? String) == owner && (w[kCGWindowLayer as String] as? Int) == 0 {
    let b = w[kCGWindowBounds as String] as? [String: Double] ?? [:]
    print("\(w[kCGWindowNumber as String] ?? 0) \(Int(b["X"] ?? 0)) \(Int(b["Y"] ?? 0)) \(Int(b["Width"] ?? 0)) \(Int(b["Height"] ?? 0)) \(w[kCGWindowName as String] as? String ?? "")")
}
