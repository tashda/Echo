import SwiftUI

public struct ToolbarAddButton: View {
    @State private var isHovered = false
    
    public init() {}

    public var body: some View {
        ZStack {
            Circle()
                .fill(isHovered ? ColorTokens.Background.secondary : ColorTokens.Background.tertiary)
                .overlay(
                    Circle()
                        .strokeBorder(ColorTokens.Separator.primary, lineWidth: 0.5)
                )
            
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .frame(width: 28, height: 28)
        .contentShape(Circle())
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}
