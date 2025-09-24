import SwiftUI
import AppKit

struct SettingsWindow: Scene {
    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(ThemeManager.shared)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedSection: SettingsSection = .appearance
    
    enum SettingsSection: String, CaseIterable, Identifiable {
        case appearance = "Appearance"
        
        var id: String { rawValue }
        
        var iconName: String {
            switch self {
            case .appearance:
                return "paintpalette.fill"
            }
        }
        
        var displayName: String { rawValue }
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar with unified liquid glass design
            VStack(spacing: 0) {
                // Header area
                VStack(alignment: .leading, spacing: 12) {
                    Text("Settings")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                }
                
                // Settings sections list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(SettingsSection.allCases) { section in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedSection = section
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: section.iconName)
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(.blue)
                                        .frame(width: 24)
                                    
                                    Text(section.displayName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)
                                    
                                    Spacer()
                                    
                                    if selectedSection == section {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(selectedSection == section ? .blue.opacity(0.08) : .clear)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                
                Spacer()
            }
            .navigationSplitViewColumnWidth(min: 240, ideal: 260, max: 320)
            .background(.ultraThinMaterial)
        } detail: {
            // Detail view with seamless glass integration
            Group {
                switch selectedSection {
                case .appearance:
                    AppearanceSettingsView()
                        .environmentObject(themeManager)
                }
            }
            .frame(minWidth: 450, minHeight: 350)
            .background(.ultraThinMaterial)
        }
        .navigationSplitViewStyle(.automatic)
        .frame(minWidth: 720, minHeight: 500)
        .toolbar(removing: .sidebarToggle)
    }
}

struct AppearanceSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.blue)
                            .padding(12)
                            .background {
                                Circle()
                                    .fill(.blue.opacity(0.15))
                            }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Appearance")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            
                            Text("Choose how Fuzee looks when you're using it")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                
                // Theme Selection Section
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Theme")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Select a theme for the interface")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Theme cards - clean design
                    HStack(spacing: 16) {
                        ForEach(AppTheme.allCases, id: \.rawValue) { theme in
                            ThemeSelectionCard(
                                theme: theme,
                                isSelected: themeManager.currentTheme == theme
                            ) {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    themeManager.currentTheme = theme
                                }
                            }
                        }
                    }
                }
                
                // Information section
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.blue)
                        
                        Text("System Integration")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Text("Fuzee follows your system appearance settings when set to 'System'. Changes take effect immediately.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 26)
                }
                
                Spacer()
            }
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct ThemeSelectionCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                // Clean theme preview
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(theme == .dark ? .black : .white)
                        .frame(width: 100, height: 75)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.separator, lineWidth: 1)
                        }
                    
                    // Mini window representation
                    VStack(spacing: 3) {
                        // Title bar
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(theme == .dark ? .white.opacity(0.1) : .black.opacity(0.1))
                            .frame(height: 10)
                        
                        // Content area
                        HStack(spacing: 3) {
                            // Sidebar
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(theme == .dark ? .white.opacity(0.2) : .black.opacity(0.2))
                                .frame(width: 24)
                            
                            // Main content
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(theme == .dark ? .white.opacity(0.05) : .black.opacity(0.05))
                        }
                        .frame(height: 40)
                    }
                    .padding(10)
                }
                
                // Theme name and icon
                VStack(spacing: 6) {
                    Image(systemName: theme.iconName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(isSelected ? .blue : .secondary)
                    
                    Text(theme.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                }
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? .blue.opacity(0.08) : .clear)
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.blue, lineWidth: 2)
                        }
                    }
            }
        }
        .buttonStyle(.plain)
        .help("Select \(theme.displayName) theme")
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
