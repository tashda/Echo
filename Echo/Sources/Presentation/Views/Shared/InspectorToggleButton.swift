import SwiftUI

struct InspectorToggleButton: View {
    let isActive: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            Image(systemName: "sidebar.right")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 26, height: 26)
                .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isActive ? Color.accentColor.opacity(0.18) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .help(isActive ? "Hide Inspector" : "Show Inspector")
        .accessibilityLabel(isActive ? "Hide Inspector" : "Show Inspector")
    }
}
