//
//  EchoApp.swift
//  Echo
//
//  Created by Kenneth Berg on 15/09/2025.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct EchoApp: App {
    @State private var coordinator = AppDirector.shared

    init() {
        EchoApp.raiseFileDescriptorLimit()
        FontRegistrar.registerBundledFonts()
        #if os(macOS)
        if let forced = ProcessInfo.processInfo.environment["ECHO_FORCE_APPEARANCE"] {
            switch forced.lowercased() {
            case "dark":
                NSApp?.appearance = NSAppearance(named: .darkAqua)
            case "light":
                NSApp?.appearance = NSAppearance(named: .aqua)
            default:
                break
            }
        }
        #endif
    }

    var body: some Scene {
        SwiftUI.WindowGroup {
            WorkspaceView()
                .environment(coordinator.projectStore)
                .environment(coordinator.connectionStore)
                .environment(coordinator.navigationStore)
                .environment(coordinator.tabStore)
                .environment(coordinator.resultSpoolConfigCoordinator)
                .environment(coordinator.diagramBuilder)
                .environment(coordinator.navigationStore.navigationState)
                .environment(coordinator.environmentState)
                .environment(coordinator.appState)
                .environment(coordinator.clipboardHistory)
                .environment(coordinator.appearanceStore)
                .environment(coordinator.notificationEngine)
                .environment(coordinator.activityEngine)
                .task { await coordinator.initialize() }
        }
        .defaultLaunchBehavior(.presented)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            QueryCommands(
                environmentState: coordinator.environmentState,
                appState: coordinator.appState,
                navigationStore: coordinator.navigationStore,
                tabStore: coordinator.tabStore,
                projectStore: coordinator.projectStore
            )
            AppSettingsCommands()
            AutocompleteInspectorCommands()
            PerformanceMonitorCommands()
            StreamingTestHarnessCommands()
            SparkleCommands()
#if os(macOS)
            ConnectMenuCommands(
                environmentState: coordinator.environmentState,
                projectStore: coordinator.projectStore,
                connectionStore: coordinator.connectionStore,
                navigationStore: coordinator.navigationStore
            )
            ViewMenuCommands(
                appState: coordinator.appState,
                navigationStore: coordinator.navigationStore,
                tabStore: coordinator.tabStore
            )
#endif
        }
        JobQueueWindow()
        UserEditorWindow()
        LoginEditorWindow()
        RoleEditorWindow()
        DatabaseEditorWindow()
        ServerEditorWindow()
        FunctionEditorWindow()
        PgRoleEditorWindow()
        PublicationEditorWindow()
        SubscriptionEditorWindow()
        TablePropertiesWindow()
        AutocompleteInspectorWindow()
        PerformanceMonitorWindow()
        StreamingTestHarnessWindow()
        SettingsWindowScene()
    }

    /// Raises the per-process file descriptor limit so NIO's kqueue and the many
    /// dedicated SQL Server connections don't exhaust the default 256 fd ceiling.
    private static func raiseFileDescriptorLimit() {
        var limits = rlimit()
        guard getrlimit(RLIMIT_NOFILE, &limits) == 0 else { return }
        limits.rlim_cur = min(limits.rlim_max, 8192)
        setrlimit(RLIMIT_NOFILE, &limits)
    }
}

#if os(macOS)
@MainActor
struct QueryCommands: Commands {
    var environmentState: EnvironmentState
    var appState: AppState
    let navigationStore: NavigationStore
    let tabStore: TabStore
    let projectStore: ProjectStore

    private var customShortcuts: [String: CustomShortcutBinding] {
        projectStore.globalSettings.customKeyboardShortcuts ?? [:]
    }

    private func key(for title: String, default defaultKey: KeyEquivalent) -> KeyEquivalent {
        customShortcuts[title]?.swiftUIKey ?? defaultKey
    }

    private func mods(for title: String, default defaultMods: EventModifiers) -> EventModifiers {
        customShortcuts[title]?.swiftUIModifiers ?? defaultMods
    }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Query Tab") {
                environmentState.openQueryTab()
            }
            .keyboardShortcut(key(for: "New Query Tab", default: "t"), modifiers: mods(for: "New Query Tab", default: [.command]))

            Button(action: {
                guard navigationStore.isWorkspaceWindowKey else { return }
                tabStore.activateNextTab()
                if appState.showTabOverview {
                    appState.showTabOverview = false
                }
            }) {
                Text("Next Tab")
            }
            .keyboardShortcut(key(for: "Next Tab", default: .tab), modifiers: mods(for: "Next Tab", default: [.control]))

            Button(action: {
                guard navigationStore.isWorkspaceWindowKey else { return }
                tabStore.activatePreviousTab()
                if appState.showTabOverview {
                    appState.showTabOverview = false
                }
            }) {
                Text("Previous Tab")
            }
            .keyboardShortcut(key(for: "Previous Tab", default: .tab), modifiers: mods(for: "Previous Tab", default: [.control, .shift]))

            Button(action: {
                guard navigationStore.isWorkspaceWindowKey else { return }
                if tabStore.reopenLastClosedTab(activate: true) != nil {
                    if appState.showTabOverview {
                        appState.showTabOverview = false
                    }
                }
            }) {
                Text("Reopen Closed Tab")
            }
            .keyboardShortcut(key(for: "Reopen Closed Tab", default: "t"), modifiers: mods(for: "Reopen Closed Tab", default: [.command, .shift]))

            Button("Close Query Tab") {
                if navigationStore.isWorkspaceWindowKey {
                    if let active = tabStore.activeTab {
                        tabStore.closeTab(id: active.id)
                    }
                } else if let keyWindow = NSApplication.shared.keyWindow {
                    keyWindow.performClose(nil)
                }
            }
            .keyboardShortcut(key(for: "Close Query Tab", default: "w"), modifiers: mods(for: "Close Query Tab", default: [.command]))
        }
    }
}

struct AutocompleteInspectorCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .help) {
            Button("Autocomplete Management") {
                openWindow(id: AutocompleteInspectorWindow.sceneID)
            }
            .keyboardShortcut("m", modifiers: [.command, .option])
        }
    }
}

struct PerformanceMonitorCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .help) {
            Button("Performance Monitor") {
                openWindow(id: PerformanceMonitorWindow.sceneID)
            }
            .keyboardShortcut("p", modifiers: [.command, .option])
        }
    }
}

struct StreamingTestHarnessCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .help) {
            Button("Streaming Test Harness") {
                openWindow(id: StreamingTestHarnessWindow.sceneID)
            }
            .keyboardShortcut("t", modifiers: [.command, .option, .shift])
        }
    }
}

struct AppSettingsCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings") {
                openWindow(id: SettingsWindowScene.sceneID)
            }
            .keyboardShortcut(",", modifiers: [.command])
        }
    }
}

struct SparkleCommands: Commands {
    private var updater = SparkleUpdater.shared

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button {
                updater.checkForUpdates()
            } label: {
                Label("Check for Updates", systemImage: "arrow.clockwise.circle")
            }
            .disabled(!updater.canCheckForUpdates)
        }
    }
}

#endif
