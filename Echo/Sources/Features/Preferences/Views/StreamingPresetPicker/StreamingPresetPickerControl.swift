import SwiftUI

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

    @State internal var selection: Selection
    @State internal var customText: String
    @State internal var showInfoPopover = false
    @State internal var showCustomPopover = false
    @State internal var isSynchronizingSelection = false

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
        LabeledContent {
            HStack(spacing: SpacingTokens.xxs2) {
                picker
                infoButton
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        } label: {
            Text(title)
        }
    }

    private var picker: some View {
        Picker("", selection: $selection) {
            ForEach(presets, id: \.self) { preset in
                Text(label(for: preset))
                    .tag(Selection.preset(preset))
            }
            Text(selection == .custom ? displayValueLabel : "Custom")
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
                rangeDescription: "\(formatter(range.lowerBound)) -- \(formatter(range.upperBound))",
                onSubmit: applyCustomValue,
                onCancel: { showCustomPopover = false }
            )
            .frame(width: 240)
        }
    }

    var infoButton: some View {
        Button(action: { showInfoPopover.toggle() }) {
            Image(systemName: "info.circle")
                .imageScale(.medium)
                .font(TypographyTokens.standard.weight(.regular))
        }
        .buttonStyle(.plain)
        .foregroundStyle(ColorTokens.Text.secondary)
        .popover(isPresented: $showInfoPopover,
                 attachmentAnchor: .rect(.bounds),
                 arrowEdge: .trailing) {
            InfoPopover(description: description, defaultLabel: defaultLabel)
        }
    }

    func label(for preset: Int) -> String { formatter(preset) }
    var displayValueLabel: String { formatter(value) }
    var defaultLabel: String { formatter(defaultValue) }

}
