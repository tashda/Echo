import SwiftUI

struct HistorySidebarView: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: SpacingTokens.lg) {
            // Clean icon design
            Image(systemName: icon)
                .font(TypographyTokens.title)
                .foregroundStyle(ColorTokens.Text.tertiary)
            
            VStack(spacing: SpacingTokens.sm) {
                Text(title)
                    .font(TypographyTokens.hero)
                    .fontWeight(.semibold)
                    .foregroundStyle(ColorTokens.Text.primary)
                
                
                Text(description)
                    .font(TypographyTokens.subheadline)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SpacingTokens.xl)
            }
            
            // Clean future features button
            Button("Coming Soon") {
                // Future functionality
            }
            .buttonStyle(.bordered)
            .disabled(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
