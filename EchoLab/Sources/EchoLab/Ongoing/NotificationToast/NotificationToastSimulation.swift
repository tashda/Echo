import Observation
import SwiftUI

/// The toasts one exhibit shows: Echo's rules (three at most, repeats count up, errors stay,
/// the hovered toast waits), with the duration from the exhibit's options.
@Observable @MainActor
final class NTSimulation {
    enum Kind { case success, info, error }

    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let kind: Kind
        let icon: String
        let message: String
        let server: String
        var link: String?
        var count = 1

        var headline: String { message.components(separatedBy: ": ").first ?? message }
        var detail: String? {
            let parts = message.components(separatedBy: ": ")
            return parts.count > 1 ? parts.dropFirst().joined(separator: ": ") : nil
        }
        var tint: Color {
            switch kind {
            case .success: ColorTokens.Status.success
            case .info: ColorTokens.Text.secondary
            case .error: ColorTokens.Status.error
            }
        }
    }

    enum Sample: CaseIterable {
        case connected, queryFailed, backupFailed, switched

        var toast: Toast {
            switch self {
            case .connected: Toast(kind: .success, icon: "checkmark.circle.fill", message: "Connected to postgres18", server: "postgres18", link: "Show Server")
            case .queryFailed: Toast(kind: .error, icon: "exclamationmark.octagon.fill", message: "Query 1 failed: relation \"public.employees\" does not exist", server: "postgres18", link: "Open Tab")
            case .backupFailed: Toast(kind: .error, icon: "exclamationmark.triangle", message: "Backup failed for sales: Operating system error 5 (Access is denied.) while writing to /var/opt/mssql/backup/sales.bak", server: "Test MSSQL", link: "Show Server")
            case .switched: Toast(kind: .info, icon: "arrow.triangle.swap", message: "Switched to sales", server: "tippr", link: "Open Tab")
            }
        }
    }

    static let maximumVisible = 3

    var toasts: [Toast] = []
    var hoveredID: UUID?
    var duration: Double = 3

    func post(_ sample: Sample) {
        var toast = sample.toast
        if let index = toasts.firstIndex(where: { $0.message == toast.message }) {
            toast = toasts.remove(at: index)
            toast.count += 1
        }
        toasts.insert(toast, at: 0)
        if toasts.count > Self.maximumVisible { toasts.removeLast() }
        scheduleDismiss(toast)
    }

    func repeatLatest() {
        guard let latest = toasts.first,
              let sample = Sample.allCases.first(where: { $0.toast.message == latest.message }) else { return post(.connected) }
        post(sample)
    }

    func dismiss(_ id: UUID) {
        toasts.removeAll { $0.id == id }
        if hoveredID == id { hoveredID = nil }
    }

    private func scheduleDismiss(_ toast: Toast) {
        guard toast.kind != .error else { return }
        let id = toast.id
        let count = toast.count
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.duration ?? 3))
            while self?.hoveredID == id { try? await Task.sleep(for: .milliseconds(300)) }
            guard let self, self.toasts.first(where: { $0.id == id })?.count == count else { return }
            self.dismiss(id)
        }
    }
}
