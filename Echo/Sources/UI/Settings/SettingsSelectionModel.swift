import SwiftUI
import Combine

@MainActor
final class SettingsSelectionModel: ObservableObject {
    @Published var selection: SettingsView.SettingsSection? = .appearance
    @Published var navigationHistory: [SettingsView.SettingsSection] = [.appearance]
    @Published var historyIndex: Int = 0

    private var isUpdatingFromHistory = false

    var canNavigateBack: Bool { historyIndex > 0 }
    var canNavigateForward: Bool { historyIndex + 1 < navigationHistory.count }

    func setSelection(_ section: SettingsView.SettingsSection?) {
        guard let newValue = section else { return }
        guard !isUpdatingFromHistory else { isUpdatingFromHistory = false; return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.historyIndex < self.navigationHistory.count - 1 {
                self.navigationHistory = Array(self.navigationHistory.prefix(self.historyIndex + 1))
            }
            if self.navigationHistory.last != newValue {
                self.navigationHistory.append(newValue)
            }
            self.historyIndex = self.navigationHistory.count - 1
            self.selection = newValue
        }
    }

    func navigateBack() {
        guard canNavigateBack else { return }
        historyIndex -= 1
        isUpdatingFromHistory = true
        selection = navigationHistory[historyIndex]
    }

    func navigateForward() {
        guard canNavigateForward else { return }
        historyIndex += 1
        isUpdatingFromHistory = true
        selection = navigationHistory[historyIndex]
    }
}
