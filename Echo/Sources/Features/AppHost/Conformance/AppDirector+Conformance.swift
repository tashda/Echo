#if DEBUG
import AppKit
import SwiftUI

/// The views Echo draws for conformance checks, by Echo Labs page id. Each draws Echo's real view
/// in the states the round's `conformance` lists (see `EchoLab/Scripts/verify-round.py`).
@MainActor
enum ConformanceSpecimens {
    static func view(page: String, state: String) -> AnyView? {
        switch page {
        case "ongoing.notification-toast-r18": AnyView(NotificationToastSpecimen(state: state))
        default: nil
        }
    }
}

extension AppDirector {
    private enum ConformanceFailure: Error {
        case noSpecimen(String)
    }

    /// Launched with `ECHO_CONFORMANCE=<request>` (by `EchoLab/Scripts/verify-round.py`): draws the
    /// page's specimen in each requested state, captures it the way Echo Labs captured the
    /// accepted round, and quits.
    func runConformanceIfRequested() {
        guard let request = ConformanceRequest.load() else { return }
        Task(name: "conformance-echo") { [environmentState, appState] in
            // Let the app finish launching before opening windows.
            try? await Task.sleep(for: .seconds(1))
            do {
                guard ConformanceSpecimens.view(page: request.page, state: "") != nil else {
                    throw ConformanceFailure.noSpecimen(request.page)
                }
                let size = CGSize(width: request.width ?? 0, height: request.height ?? 0)
                _ = try await ConformanceCapture.run(request: request, states: request.states ?? [], size: size) { state in
                    AnyView(ConformanceSpecimens.view(page: request.page, state: state)
                        .environment(environmentState)
                        .environment(appState))
                }
                exit(0)
            } catch {
                FileHandle.standardError.write(Data("Conformance capture failed: \(error)\n".utf8))
                exit(1)
            }
        }
    }
}
#endif
