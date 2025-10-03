import SwiftUI

struct HistorySidebarView: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 24) {
            // Clean icon design
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            
            VStack(spacing: 12) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
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
