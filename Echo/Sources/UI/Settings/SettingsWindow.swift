import SwiftUI
import Foundation
import Combine
#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Primary settings scene built with a native `NavigationSplitView`.
struct SettingsWindow: Scene {
    static let sceneID = "settings"

    var body: some Scene {
        Window("Settings", id: Self.sceneID) {
            SettingsView()
                .environmentObject(AppCoordinator.shared.appModel)
                .environmentObject(AppCoordinator.shared.appState)
                .environmentObject(AppCoordinator.shared.clipboardHistory)
                .environmentObject(ThemeManager.shared)
        }
        .defaultSize(width: 720, height: 520)
    }

}

/// Hosts the sidebar/detail split view and renders each settings section.
struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var clipboardHistory: ClipboardHistoryStore
    @EnvironmentObject private var themeManager: ThemeManager

    enum SettingsSection: String, CaseIterable, Identifiable {
        case appearance
        case queryResults
        case echoSense
        case diagrams
        case applicationCache
        case keyboardShortcuts

        var id: String { rawValue }

        var title: String {
            switch self {
            case .appearance: return "Appearance"
            case .queryResults: return "Query Results"
            case .echoSense: return "EchoSense"
            case .diagrams: return "Diagrams"
            case .applicationCache: return "Application Cache"
            case .keyboardShortcuts: return "Keyboard Shortcuts"
        }
        }

        var systemImage: String? {
            switch self {
            case .appearance: return "paintbrush"
            case .queryResults: return "tablecells"
            case .diagrams: return "rectangle.connected.to.line.below"
            case .applicationCache: return "internaldrive"
            case .keyboardShortcuts: return "command"
            case .echoSense: return nil
        }
        }

        var assetImageName: String? {
            switch self {
            case .echoSense:
                return "bulb.bolt"
            default:
                return nil
            }
        }
    }

#if os(macOS)
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
#endif
    @State private var preferredColumn: NavigationSplitViewColumn = .sidebar
    @State private var selection: SettingsSection? = .appearance
    @State private var navigationHistory: [SettingsSection] = [.appearance]
    @State private var historyIndex: Int = 0
    @State private var isUpdatingFromHistory = false

    private let fixedSidebarWidth: CGFloat = 280
#if os(macOS)
    private let headerHeight: CGFloat = 60
#endif

    var body: some View {
        settingsSplitView
        .frame(minWidth: 720, minHeight: 520)
        .onAppear {
            if selection == nil {
                selection = .appearance
            }
#if os(macOS)
            columnVisibility = .all
#endif
            navigationHistory = [.appearance]
            historyIndex = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsSection)) { notification in
            guard let raw = notification.object as? String,
                  let section = SettingsSection(rawValue: raw) else { return }
            selection = section
            preferredColumn = .sidebar
#if os(macOS)
            columnVisibility = .all
#endif
        }
        .onChange(of: selection) { _, newValue in
            guard !isUpdatingFromHistory else {
                isUpdatingFromHistory = false
                return
            }
            guard let newValue else { return }
            if historyIndex < navigationHistory.count - 1 {
                navigationHistory = Array(navigationHistory.prefix(historyIndex + 1))
            }
            navigationHistory.append(newValue)
            historyIndex = navigationHistory.count - 1
        }
        .accentColor(themeManager.accentColor)
        .preferredColorScheme(themeManager.effectiveColorScheme)
        .background(themeManager.windowBackground)
    }

    @ViewBuilder
    private var settingsSplitView: some View {
#if os(macOS)
        NavigationSplitView(columnVisibility: $columnVisibility, preferredCompactColumn: $preferredColumn) {
            sidebar
        } detail: {
            detailContent
        }
        .toolbar(removing: .sidebarToggle)
        .toolbarBackground(.hidden, for: .windowToolbar)
#else
        NavigationSplitView(preferredCompactColumn: $preferredColumn) {
            sidebar
        } detail: {
            detailContent
        }
#endif
    }

    private var sidebar: some View {
        List(selection: $selection) {
            ForEach(SettingsSection.allCases) { section in
                Label {
                    Text(section.title)
                } icon: {
                    iconView(for: section)
                }
                .tag(section)
            }
        }
        .navigationTitle("Settings")
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: fixedSidebarWidth, ideal: fixedSidebarWidth, max: fixedSidebarWidth)
#if os(macOS)
        .background(Color.clear)
#else
        .scrollContentBackground(.hidden)
        .background(themeManager.surfaceBackgroundColor)
#endif
    }

    private var detailContent: some View {
#if os(macOS)
        ZStack(alignment: .topLeading) {
            detailBaseContent
                .padding(.top, headerHeight)

            DetailHeader(
                title: selection?.title ?? "Settings",
                canNavigateBack: canNavigateBack,
                canNavigateForward: canNavigateForward,
                onNavigateBack: navigateBack,
                onNavigateForward: navigateForward
            )
            .frame(height: headerHeight)
        }
        .frame(minWidth: 560, minHeight: 420)
        .background(themeManager.surfaceBackgroundColor)
#else
        detailBaseContent
            .frame(minWidth: 560, minHeight: 420)
            .background(themeManager.surfaceBackgroundColor)
            .navigationTitle(selection?.title ?? "Settings")
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button(action: navigateBack, label: {
                        Image(systemName: "chevron.left")
                    })
                    .disabled(!canNavigateBack)

                    Button(action: navigateForward, label: {
                        Image(systemName: "chevron.right")
                    })
                    .disabled(!canNavigateForward)
                }
                ToolbarItem(placement: .principal) {
                    Text(selection?.title ?? "Settings")
                        .font(.system(size: 28, weight: .bold))
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
#endif
    }

    private var detailBaseContent: some View {
        Group {
            if let selection {
                sectionView(for: selection)
                    .id(selection)
            } else {
                ContentUnavailableView {
                    Label("Select a Section", systemImage: "slider.horizontal.3")
                } description: {
                    Text("Choose a settings category to view its options.")
                }
            }
        }
    }

    @ViewBuilder
    private func sectionView(for section: SettingsSection) -> some View {
        switch section {
        case .appearance:
            AppearanceSettingsView()
                .environmentObject(appModel)
                .environmentObject(appState)
                .environmentObject(themeManager)

        case .queryResults:
            QueryResultsSettingsView()
                .environmentObject(appModel)
                .environmentObject(appState)
                .environmentObject(themeManager)

        case .echoSense:
            EchoSenseSettingsView()
                .environmentObject(appModel)
                .environmentObject(appState)
                .environmentObject(themeManager)

        case .diagrams:
            DiagramSettingsView()
                .environmentObject(appModel)
                .environmentObject(themeManager)

        case .applicationCache:
            ApplicationCacheSettingsView()
                .environmentObject(clipboardHistory)

        case .keyboardShortcuts:
            KeyboardShortcutsSettingsView()
        }
    }

#if os(macOS)
    @ViewBuilder
    private func iconView(for section: SettingsSection) -> some View {
        if let systemName = section.systemImage {
            Image(systemName: systemName)
        } else if let assetName = section.assetImageName {
            Image(assetName)
                .renderingMode(.template)
        } else {
            Image(systemName: "square")
        }
    }
#else
    @ViewBuilder
    private func iconView(for section: SettingsSection) -> some View {
        if let systemName = section.systemImage {
            Image(systemName: systemName)
        } else if let assetName = section.assetImageName {
            Image(assetName)
                .renderingMode(.template)
        } else {
            Image(systemName: "square")
        }
    }
#endif


#if os(macOS)
    private var canNavigateBack: Bool {
        historyIndex > 0
    }

    private var canNavigateForward: Bool {
        historyIndex + 1 < navigationHistory.count
    }

    private func navigateBack() {
        guard canNavigateBack else { return }
        historyIndex -= 1
        isUpdatingFromHistory = true
        selection = navigationHistory[historyIndex]
    }

    private func navigateForward() {
        guard canNavigateForward else { return }
        historyIndex += 1
        isUpdatingFromHistory = true
        selection = navigationHistory[historyIndex]
    }

#else
    private var canNavigateBack: Bool { historyIndex > 0 }
    private var canNavigateForward: Bool { historyIndex + 1 < navigationHistory.count }
    private func navigateBack() { if canNavigateBack { historyIndex -= 1; isUpdatingFromHistory = true; selection = navigationHistory[historyIndex] } }
    private func navigateForward() { if canNavigateForward { historyIndex += 1; isUpdatingFromHistory = true; selection = navigationHistory[historyIndex] } }
#endif
}

#Preview("Settings Window") {
    SettingsView()
}

extension Notification.Name {
    static let openSettingsSection = Notification.Name("com.fuzee.settings.openSection")
}

#if os(macOS)
private struct DetailHeader: View {
    let title: String
    let canNavigateBack: Bool
    let canNavigateForward: Bool
    let onNavigateBack: () -> Void
    let onNavigateForward: () -> Void

    var body: some View {
        VisualEffectBlur(material: .underWindowBackground, blendingMode: .withinWindow)
            .overlay(
                HStack(spacing: 10) {
                    headerButton(systemName: "chevron.left", isEnabled: canNavigateBack, action: onNavigateBack)
                    headerButton(systemName: "chevron.right", isEnabled: canNavigateForward, action: onNavigateForward)
                    Text(title)
                        .font(.system(size: 22, weight: .semibold))
                        .padding(.leading, 4)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, 8)
            .padding(.top, 6)
    }

    private func headerButton(systemName: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 26, height: 24)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .foregroundStyle(isEnabled ? Color.primary : Color.primary.opacity(0.35))
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(isEnabled ? 0.12 : 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(isEnabled ? 0.18 : 0.08), lineWidth: 1)
        )
    }
}

private struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
    }
}
#else
private struct DetailHeader: View {
    let title: String
    let canNavigateBack: Bool
    let canNavigateForward: Bool
    let onNavigateBack: () -> Void
    let onNavigateForward: () -> Void

    var body: some View { EmptyView() }
}
#endif
