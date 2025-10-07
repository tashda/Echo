//
//  InspectorViewController.swift
//  Echo
//
//  Created by Codex on 07/10/2025.
//

import AppKit
import SwiftUI

final class InspectorViewController: NSViewController {
    private let appModel: AppModel
    private let appState: AppState
    private var hostingController: NSHostingController<InspectorWrapperView>?

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
        let inspectorView = InspectorWrapperView(appModel: appModel, appState: appState)
        let hosting = NSHostingController(rootView: inspectorView)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        hosting.view.wantsLayer = false

        // Mirror sidebar vibrancy so the inspector inherits the system glass treatment.
        let container = NSVisualEffectView()
        container.state = .active
        container.blendingMode = .withinWindow
        if #available(macOS 13.0, *) {
            container.material = .hudWindow
        } else if #available(macOS 11.0, *) {
            container.material = .underWindowBackground
        } else {
            container.material = .windowBackground
        }
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

private struct InspectorWrapperView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject var appState: AppState

    var body: some View {
        InfoSidebarView()
            .environmentObject(appModel)
            .environmentObject(appState)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
    }
}
