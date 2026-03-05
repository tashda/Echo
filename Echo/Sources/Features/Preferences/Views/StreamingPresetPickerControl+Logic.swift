import SwiftUI

extension StreamingPresetPickerControl {
    func handleSelectionChange(_ newSelection: Selection) {
        switch newSelection {
        case .preset(let preset):
            setValue(preset)
            showCustomPopover = false
        case .custom:
            customText = String(value)
            if !isSynchronizingSelection {
                showCustomPopover = true
            }
        }
        isSynchronizingSelection = false
    }

    func syncSelection(with newValue: Int) {
        if presets.contains(newValue) {
            let target = Selection.preset(newValue)
            if selection != target {
                isSynchronizingSelection = true
                selection = target
            }
            customText = String(newValue)
            return
        }

        if selection != .custom {
            isSynchronizingSelection = true
            selection = .custom
        }
        customText = String(newValue)
    }

    func applyCustomValue() {
        guard let raw = Int(customText) else {
            customText = String(value)
            return
        }
        setValue(raw)
        showCustomPopover = false
    }

    func resetCustomDraft() {
        customText = String(value)
    }

    func setValue(_ newValue: Int) {
        let clamped = clamp(newValue)
        value = clamped
        customText = String(clamped)
    }

    func clamp(_ candidate: Int) -> Int {
        min(max(candidate, range.lowerBound), range.upperBound)
    }
}
