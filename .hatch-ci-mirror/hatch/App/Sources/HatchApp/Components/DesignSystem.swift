import SwiftUI
import HatchCore

/// Shared look from DESIGN.md. New UI uses these before it invents anything (decisions LK1 to LK11).
enum HX {
    /// A project's tile colour, stable for its key. Colour is otherwise reserved for turn and problems (LK5).
    static func projectTint(_ key: String) -> Color {
        let palette: [Color] = [
            Color(red: 0.17, green: 0.35, blue: 0.76), Color(red: 0.04, green: 0.43, blue: 0.50),
            Color(red: 0.55, green: 0.30, blue: 0.70), Color(red: 0.70, green: 0.33, blue: 0.04),
            Color(red: 0.18, green: 0.48, blue: 0.27), Color(red: 0.29, green: 0.36, blue: 0.43),
        ]
        let sum = key.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return palette[sum % palette.count]
    }
}

extension Status {
    /// The phase glyph: how far along the ticket is. Colour comes from the turn (LK1).
    var phaseSymbol: String {
        switch self {
        case .draft: "circle.dashed"
        case .checking: "circle.dotted"
        case .needsAnswers: "questionmark.circle.fill"
        case .ready: "circle"
        case .preparing, .revising, .building, .fixing: "circle.lefthalf.filled"
        case .yourCall, .toVerify: "circle.inset.filled"
        case .accepted: "checkmark.circle"
        case .merged, .done: "checkmark.circle.fill"
        case .blocked: "exclamationmark.circle"
        case .parked: "pause.circle"
        case .dropped: "xmark.circle"
        }
    }
}

/// A small coloured tile with the project's first letter.
struct ProjectTile: View {
    let name: String
    let key: String
    var size: CGFloat = 20

    var body: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: size * 0.55, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(HX.projectTint(key), in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }
}

/// The text dock (LK3): Echo's glass capsule with one equal slot per section, the current one a soft accent fill.
/// Six or more sections become a pull-down, as in Echo's TabSectionPicker.
struct HXDock<Value: Hashable>: View {
    struct Item: Identifiable {
        let id: Value
        let title: String
        var count: Int? = nil
    }

    let items: [Item]
    @Binding var selection: Value
    static var maximumSlots: Int { 5 }

    var body: some View {
        if items.count > Self.maximumSlots {
            Picker("Section", selection: $selection) {
                ForEach(items) { Text($0.title).tag($0.id) }
            }
            .pickerStyle(.menu)
            .controlSize(.large)
            .labelsHidden()
            .fixedSize()
        } else {
            GlassEffectContainer {
                HStack(spacing: 0) {
                    ForEach(items) { item in
                        HXDockSlot(item: item, isCurrent: item.id == selection) { selection = item.id }
                    }
                }
                .padding(3)
                .glassEffect(.regular, in: .capsule)
                .overlay(Capsule().strokeBorder(.separator.opacity(0.6), lineWidth: 0.6))
                .shadow(color: .black.opacity(0.08), radius: 4, y: 1)
            }
            .fixedSize()
        }
    }
}

private struct HXDockSlot<Value: Hashable>: View {
    let item: HXDock<Value>.Item
    let isCurrent: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(item.title)
                if let count = item.count {
                    Text("\(count)").font(.caption2).monospacedDigit().opacity(0.75)
                }
            }
            .font(.callout.weight(isCurrent ? .semibold : .regular))
            .foregroundStyle(isCurrent ? Color.accentColor : (hovering ? Color.primary : Color.secondary))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background { if isCurrent { Capsule().fill(Color.accentColor.opacity(0.16)) } }
            .contentShape(Capsule())
            .scaleEffect(hovering && !isCurrent ? 1.04 : 1)
            .animation(.easeOut(duration: 0.12), value: hovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}

/// A glass menu button with an icon and a label and no arrow (LK10). Use for "More" and for actions that need a choice.
struct HXMenuButton<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        Menu(content: content) { Label(title, systemImage: symbol) }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(.glass)
            .fixedSize()
    }
}
