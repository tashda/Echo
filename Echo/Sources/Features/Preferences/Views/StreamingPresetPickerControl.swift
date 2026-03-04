import SwiftUI
#if os(macOS)
import AppKit
private typealias StreamingPopoverFont = NSFont
#elseif canImport(UIKit)
import UIKit
private typealias StreamingPopoverFont = UIFont
#endif

struct StreamingPresetPickerControl: View {
    enum Selection: Hashable {
        case preset(Int)
        case custom
    }

    let title: String
    @Binding var value: Int
    let description: String
    let presets: [Int]
    let range: ClosedRange<Int>
    let formatter: (Int) -> String
    let defaultValue: Int

    @State private var selection: Selection
    @State private var customText: String
    @State private var showInfoPopover = false
    @State private var showCustomPopover = false
    @State private var isSynchronizingSelection = false

    init(title: String,
         value: Binding<Int>,
         description: String,
         presets: [Int],
         range: ClosedRange<Int>,
         formatter: @escaping (Int) -> String,
         defaultValue: Int) {
        self.title = title
        self._value = value
        self.description = description
        self.presets = presets
        self.range = range
        self.formatter = formatter
        self.defaultValue = defaultValue

        let initialValue = value.wrappedValue
        if presets.contains(initialValue) {
            _selection = State(initialValue: .preset(initialValue))
        } else {
            _selection = State(initialValue: .custom)
        }
        _customText = State(initialValue: String(initialValue))
    }

    var body: some View {
        content
        .onChange(of: selection, initial: false) { _, newSelection in
            handleSelectionChange(newSelection)
        }
        .onChange(of: value, initial: false) { _, newValue in
            syncSelection(with: newValue)
        }
        .onChange(of: showCustomPopover) { _, isPresented in
            if !isPresented {
                resetCustomDraft()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
#if os(macOS)
        macRow
#else
        iOSRow
#endif
    }

#if os(macOS)
    private var macRow: some View {
        LabeledContent {
            HStack(spacing: 6) {
                macPicker
                infoButton
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        } label: {
            Text(title)
                .font(.system(size: 13))
        }
    }

    private var macPicker: some View {
        Picker("", selection: $selection) {
            ForEach(presets, id: \.self) { preset in
                Text(label(for: preset))
                    .tag(Selection.preset(preset))
            }
            Text(selection == .custom ? displayValueLabel : "Custom…")
                .tag(Selection.custom)
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .controlSize(.regular)
        .frame(minWidth: 120, idealWidth: 160, maxWidth: 200, alignment: .trailing)
        .popover(isPresented: $showCustomPopover,
                 attachmentAnchor: .rect(.bounds),
                 arrowEdge: .trailing) {
            CustomValuePopover(
                title: title,
                text: $customText,
                rangeDescription: "\(formatter(range.lowerBound)) – \(formatter(range.upperBound))",
                onSubmit: applyCustomValue,
                onCancel: { showCustomPopover = false }
            )
            .frame(width: 240)
        }
    }
#else
    private var iOSRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, alignment: .leading)

            iOSPicker

            infoButton
        }
        .frame(height: 44)
        .padding(.vertical, 1.5)
        .padding(.horizontal, 10)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
#endif

    private var infoButton: some View {
        Button(action: { showInfoPopover.toggle() }) {
            Image(systemName: "info.circle")
                .imageScale(.medium)
                .font(.system(size: 13, weight: .regular))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .popover(isPresented: $showInfoPopover,
                 attachmentAnchor: .rect(.bounds),
                 arrowEdge: .trailing) {
            InfoPopover(description: description, defaultLabel: defaultLabel)
        }
    }

    private func handleSelectionChange(_ newSelection: Selection) {
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

    private func syncSelection(with newValue: Int) {
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

    private func applyCustomValue() {
        guard let raw = Int(customText) else {
            customText = String(value)
            return
        }
        setValue(raw)
        showCustomPopover = false
    }

    private func resetCustomDraft() {
        customText = String(value)
    }

    private func setValue(_ newValue: Int) {
        let clamped = clamp(newValue)
        value = clamped
        customText = String(clamped)
    }

    private func clamp(_ candidate: Int) -> Int {
        min(max(candidate, range.lowerBound), range.upperBound)
    }

    private func label(for preset: Int) -> String {
        formatter(preset)
    }

    private var displayValueLabel: String {
        formatter(value)
    }

    private var defaultLabel: String {
        formatter(defaultValue)
    }

    private var rowBackground: some View {
#if os(macOS)
        Color.clear
#else
        Color(uiColor: .systemBackground).opacity(0.8)
#endif
    }

#if !os(macOS)
    private var iOSPicker: some View {
        Picker(selection: $selection) {
            ForEach(presets, id: \.self) { preset in
                Text(label(for: preset)).tag(Selection.preset(preset))
            }
            Text("Custom…").tag(Selection.custom)
        } label: {
            EmptyView()
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .fixedSize()
        .popover(isPresented: $showCustomPopover, attachmentAnchor: .rect(.bounds), arrowEdge: .trailing) {
            CustomValuePopover(
                title: title,
                text: $customText,
                rangeDescription: "\(formatter(range.lowerBound)) – \(formatter(range.upperBound))",
                onSubmit: applyCustomValue,
                onCancel: { showCustomPopover = false }
            )
        }
    }
#endif

    private struct CustomValuePopover: View {
        let title: String
        @Binding var text: String
        let rangeDescription: String
        let onSubmit: () -> Void
        let onCancel: () -> Void
        @FocusState private var fieldFocused: Bool

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Custom \(title)")
                    .font(.headline)

                TextField("Value", text: $text)
                    .textFieldStyle(.roundedBorder)
#if os(iOS)
                    .keyboardType(.numberPad)
#endif
                    .focused($fieldFocused)

                Text("Allowed range: \(rangeDescription)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Spacer()
                    Button("Cancel", role: .cancel, action: onCancel)
                    Button("Done", action: onSubmit)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(16)
            .frame(width: 240)
            .onAppear {
                DispatchQueue.main.async {
                    fieldFocused = true
                }
            }
        }
    }

    private struct InfoPopover: View {
        let description: String
        let defaultLabel: String

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                Text("Default: \(defaultLabel)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(width: preferredWidth)
        }

        private var preferredWidth: CGFloat {
            let padding: CGFloat = 32
            let minWidth: CGFloat = 220
            let maxWidth: CGFloat = 320
            let contentLimit = maxWidth - padding

            let descriptionWidth = measuredWidth(for: description, font: platformFont(size: 13), limit: contentLimit)
            let defaultWidth = measuredWidth(for: "Default: \(defaultLabel)", font: platformFont(size: 12), limit: contentLimit)
            let contentWidth = max(descriptionWidth, defaultWidth)
            return min(maxWidth, max(minWidth, contentWidth + padding))
        }

        private func platformFont(size: CGFloat, weight: StreamingPopoverFont.Weight = .regular) -> StreamingPopoverFont {
#if os(macOS)
            NSFont.systemFont(ofSize: size, weight: weight)
#else
            UIFont.systemFont(ofSize: size, weight: weight)
#endif
        }

        private func measuredWidth(for text: String, font: StreamingPopoverFont, limit: CGFloat) -> CGFloat {
            guard !text.isEmpty else { return 0 }
            let constraint = CGSize(width: limit, height: .greatestFiniteMagnitude)
#if os(macOS)
            let rect = NSAttributedString(string: text, attributes: [.font: font])
                .boundingRect(with: constraint, options: [.usesLineFragmentOrigin, .usesFontLeading])
#else
            let rect = (text as NSString).boundingRect(with: constraint, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font], context: nil)
#endif
            return ceil(rect.width)
        }
    }
}
