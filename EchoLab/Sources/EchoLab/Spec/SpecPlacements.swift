import SwiftUI

/// Where each element's badge goes. Badges sit above their element and step aside when they
/// would cover another badge, so every ID stays readable.
struct SpecPlacement {
    let number: String
    let rect: CGRect
    let badge: CGPoint
}

enum SpecPlacements {
    static func compute(_ anchors: [String: Anchor<CGRect>], _ proxy: GeometryProxy) -> [SpecPlacement] {
        let size = CGSize(width: 32, height: 14)
        var taken: [CGRect] = []
        var result: [SpecPlacement] = []
        let order = anchors.keys.sorted { $0.compare($1, options: .numeric) == .orderedAscending }
        for number in order {
            guard let anchor = anchors[number] else { continue }
            let rect = proxy[anchor]
            func origin(column: Int, row: Int) -> CGPoint {
                CGPoint(x: min(max(rect.minX + CGFloat(column) * (size.width + 2), 0), max(proxy.size.width - size.width, 0)),
                        y: max(rect.minY - size.height - 3 - CGFloat(row) * (size.height + 2), 0))
            }
            var frame = CGRect(origin: origin(column: 0, row: 0), size: size)
            var step = 0
            while taken.contains(where: { $0.insetBy(dx: -1, dy: -1).intersects(frame) }), step < 40 {
                step += 1
                frame = CGRect(origin: origin(column: step % 8, row: step / 8), size: size)
            }
            taken.append(frame)
            result.append(SpecPlacement(number: number, rect: rect, badge: CGPoint(x: frame.midX, y: frame.midY)))
        }
        return result
    }
}

struct SpecHotspot: View {
    let label: String
    let isSelected: Bool
    let showsBadge: Bool

    var body: some View {
        Text(label)
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white)
            .frame(width: 32, height: 14)
            .background(isSelected ? Color.red : Color.accentColor, in: Capsule())
            .opacity(showsBadge ? 1 : 0)
            .contentShape(Capsule())
    }
}
