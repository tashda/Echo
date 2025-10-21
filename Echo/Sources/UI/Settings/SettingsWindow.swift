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
        .toolbarBackground(.visible, for: .windowToolbar)
        .toolbarBackground(.ultraThinMaterial, for: .windowToolbar)
        .background(
            TitlebarAccessoryBridge(
                title: selection?.title ?? "Settings",
                canNavigateBack: canNavigateBack,
                canNavigateForward: canNavigateForward,
                onNavigateBack: navigateBack,
                onNavigateForward: navigateForward
            )
        )
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
        detailBaseContent
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
private struct TitlebarAccessoryBridge: NSViewRepresentable {
    let title: String
    let canNavigateBack: Bool
    let canNavigateForward: Bool
    let onNavigateBack: () -> Void
    let onNavigateForward: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(title: title,
                    canNavigateBack: canNavigateBack,
                    canNavigateForward: canNavigateForward,
                    onNavigateBack: onNavigateBack,
                    onNavigateForward: onNavigateForward)
    }

    func makeNSView(context: Context) -> NSView {
        let view = AttachmentView()
        view.onWindowChange = { window in
            context.coordinator.update(window: window,
                                       title: title,
                                       canNavigateBack: canNavigateBack,
                                       canNavigateForward: canNavigateForward,
                                       onNavigateBack: onNavigateBack,
                                       onNavigateForward: onNavigateForward)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.update(window: nsView.window,
                                   title: title,
                                   canNavigateBack: canNavigateBack,
                                   canNavigateForward: canNavigateForward,
                                   onNavigateBack: onNavigateBack,
                                   onNavigateForward: onNavigateForward)
        if let attachment = nsView as? AttachmentView {
            attachment.onWindowChange = { window in
                context.coordinator.update(window: window,
                                           title: title,
                                           canNavigateBack: canNavigateBack,
                                           canNavigateForward: canNavigateForward,
                                           onNavigateBack: onNavigateBack,
                                           onNavigateForward: onNavigateForward)
            }
        }
    }

    final class Coordinator {
        private var accessory: NSTitlebarAccessoryViewController?
        private var hostingView: NSHostingView<TitlebarAccessoryView>?
        private var currentWindow: NSWindow?

        init(title: String,
             canNavigateBack: Bool,
             canNavigateForward: Bool,
             onNavigateBack: @escaping () -> Void,
             onNavigateForward: @escaping () -> Void) {
            hostingView = NSHostingView(rootView: TitlebarAccessoryView(
                title: title,
                canNavigateBack: canNavigateBack,
                canNavigateForward: canNavigateForward,
                onNavigateBack: onNavigateBack,
                onNavigateForward: onNavigateForward
            ))
        }

        func update(window: NSWindow?,
                    title: String,
                    canNavigateBack: Bool,
                    canNavigateForward: Bool,
                    onNavigateBack: @escaping () -> Void,
                    onNavigateForward: @escaping () -> Void) {
            guard let window else { return }

            configureWindow(window)

            let accessory = accessory ?? makeAccessory(for: window)
            accessory.view = hostingView ?? NSHostingView(rootView: TitlebarAccessoryView(
                title: title,
                canNavigateBack: canNavigateBack,
                canNavigateForward: canNavigateForward,
                onNavigateBack: onNavigateBack,
                onNavigateForward: onNavigateForward
            ))

            if hostingView == nil {
                hostingView = accessory.view as? NSHostingView<TitlebarAccessoryView>
            }

            hostingView?.rootView = TitlebarAccessoryView(
                title: title,
                canNavigateBack: canNavigateBack,
                canNavigateForward: canNavigateForward,
                onNavigateBack: onNavigateBack,
                onNavigateForward: onNavigateForward
            )

            currentWindow = window

            if window.titlebarAccessoryViewControllers.contains(accessory) == false {
                window.addTitlebarAccessoryViewController(accessory)
            }
        }

        private func configureWindow(_ window: NSWindow) {
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.toolbarStyle = .unified
            window.toolbar?.showsBaselineSeparator = false
            window.toolbar?.allowsExtensionItems = false
        }

        @discardableResult
        private func makeAccessory(for window: NSWindow) -> NSTitlebarAccessoryViewController {
            if let accessory { return accessory }
            let controller = NSTitlebarAccessoryViewController()
            controller.layoutAttribute = .left
            controller.fullScreenMinHeight = 56
            accessory = controller
            return controller
        }
    }

    private final class AttachmentView: NSView {
        var onWindowChange: ((NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindowChange?(window)
        }
    }
}

private struct TitlebarAccessoryView: View {
    let title: String
    let canNavigateBack: Bool
    let canNavigateForward: Bool
    let onNavigateBack: () -> Void
    let onNavigateForward: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            NavigationSegmentControl(
                canNavigateBack: canNavigateBack,
                canNavigateForward: canNavigateForward,
                onBack: onNavigateBack,
                onForward: onNavigateForward
            )
            .frame(width: 66)

            Text("Settings")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 40)

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 22)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Material.ultraThin)
                        .shadow(color: Color.black.opacity(0.12), radius: 12, y: 8)
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

private struct NavigationSegmentControl: NSViewRepresentable {
    let canNavigateBack: Bool
    let canNavigateForward: Bool
    let onBack: () -> Void
    let onForward: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(images: [chevron("chevron.left"), chevron("chevron.right")], trackingMode: .momentary, target: context.coordinator, action: #selector(Coordinator.handle(_:)))
        control.segmentStyle = .separated
        control.controlSize = .small
        control.setWidth(30, forSegment: 0)
        control.setWidth(30, forSegment: 1)
        update(control)
        return control
    }

    func updateNSView(_ nsView: NSSegmentedControl, context: Context) {
        context.coordinator.parent = self
        update(nsView)
    }

    private func update(_ control: NSSegmentedControl) {
        control.setEnabled(canNavigateBack, forSegment: 0)
        control.setEnabled(canNavigateForward, forSegment: 1)
    }

    private func chevron(_ name: String) -> NSImage {
        NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? NSImage()
    }

    final class Coordinator: NSObject {
        var parent: NavigationSegmentControl

        init(parent: NavigationSegmentControl) {
            self.parent = parent
        }

        @objc func handle(_ sender: NSSegmentedControl) {
            switch sender.selectedSegment {
            case 0: parent.onBack()
            case 1: parent.onForward()
            default: break
            }
            sender.selectedSegment = -1
        }
    }
}
#endif
