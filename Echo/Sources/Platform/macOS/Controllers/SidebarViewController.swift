//
//  SidebarViewController.swift
//  Echo
//
//  Created by Codex on 07/10/2025.
//

import AppKit
import SwiftUI

final class SidebarViewController: NSViewController {
    private let appModel: AppModel
    private let appState: AppState
    private var hostingController: NSHostingController<SidebarWrapperView>?

    init(appModel: AppModel, appState: AppState) {
        self.appModel = appModel
        self.appState = appState
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let sidebarView = SidebarWrapperView(
            appModel: appModel,
            appState: appState
        )
        let hosting = NSHostingController(rootView: sidebarView)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor.clear.cgColor

        let container = NSView()
        container.addSubview(hosting.view)

        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        self.hostingController = hosting
        self.view = container
    }
}

private struct SidebarWrapperView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject var appState: AppState
    @State private var showingConnectionEditor = false

    var body: some View {
        SidebarView(
            selectedConnectionID: $appModel.selectedConnectionID,
            selectedIdentityID: $appModel.selectedIdentityID,
            onAddConnection: {
                showingConnectionEditor = true
            }
        )
        .environmentObject(appModel)
        .environmentObject(appState)
        .ignoresSafeArea()
        .sheet(isPresented: $showingConnectionEditor) {
            ConnectionEditorView(
                connection: appModel.selectedConnection,
                onSave: { connection, password, action in
                    Task {
                        await appModel.upsertConnection(connection, password: password)
                        if action == .saveAndConnect {
                            await appModel.connect(to: connection)
                        }
                    }
                }
            )
            .environmentObject(appModel)
            .environmentObject(appState)
        }
    }
}
