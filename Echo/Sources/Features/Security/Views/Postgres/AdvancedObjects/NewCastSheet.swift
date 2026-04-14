import SwiftUI
import PostgresKit

struct NewCastSheet: View {
    let viewModel: PostgresAdvancedObjectsViewModel
    let onComplete: () -> Void

    enum CastMethod: String, CaseIterable {
        case withFunction = "WITH FUNCTION"
        case withoutFunction = "WITHOUT FUNCTION"
        case withInout = "WITH INOUT"
    }

    enum CastContext: String, CaseIterable {
        case explicit = "Explicit"
        case assignment = "Assignment"
        case implicit = "Implicit"
    }

    @State private var sourceType = ""
    @State private var targetType = ""
    @State private var method: CastMethod = .withoutFunction
    @State private var functionName = ""
    @State private var context: CastContext = .explicit
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        !sourceType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !targetType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && (method != .withFunction || !functionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        && !isSubmitting
    }

    var body: some View {
        SheetLayout(
            title: "New Cast",
            icon: "arrow.triangle.swap",
            subtitle: "Define a type conversion between two data types.",
            primaryAction: "Create",
            canSubmit: isFormValid,
            isSubmitting: isSubmitting,
            errorMessage: errorMessage,
            onSubmit: { await submit() },
            onCancel: { onComplete() }
        ) {
            Form {
                Section("Cast Definition") {
                    PropertyRow(title: "Source Type", info: "The source data type for the cast") {
                        PostgresDataTypePicker(selection: $sourceType, prompt: "e.g. integer")
                    }
                    PropertyRow(title: "Target Type", info: "The target data type to cast to") {
                        PostgresDataTypePicker(selection: $targetType, prompt: "e.g. text")
                    }
                    PropertyRow(title: "Method", info: "How the cast is performed. WITH FUNCTION uses a named function, WITHOUT FUNCTION for binary-coercible types, WITH INOUT uses I/O functions") {
                        Picker("", selection: $method) {
                            ForEach(CastMethod.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    if method == .withFunction {
                        PropertyRow(title: "Function Name", info: "The function that performs the cast conversion") {
                            TextField("", text: $functionName, prompt: Text("e.g. int4_to_text"))
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    PropertyRow(title: "Context", info: "EXPLICIT requires an explicit CAST(). AS ASSIGNMENT allows implicit cast in assignment context. AS IMPLICIT allows implicit cast anywhere (use with caution)") {
                        Picker("", selection: $context) {
                            ForEach(CastContext.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 480, idealWidth: 540, minHeight: 380)
    }

    private func submit() async {
        let trimmedSource = sourceType.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTarget = targetType.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSource.isEmpty, !trimmedTarget.isEmpty else { return }

        if method == .withFunction {
            let trimmedFunction = functionName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedFunction.isEmpty else { return }
        }

        isSubmitting = true
        errorMessage = nil

        let functionValue: String? = switch method {
        case .withFunction:
            functionName.trimmingCharacters(in: .whitespacesAndNewlines)
        case .withoutFunction:
            nil
        case .withInout:
            nil
        }

        await viewModel.createCast(
            sourceType: trimmedSource,
            targetType: trimmedTarget,
            function: functionValue,
            asAssignment: context == .assignment,
            asImplicit: context == .implicit
        )

        if viewModel.casts.contains(where: { $0.sourceType == trimmedSource && $0.targetType == trimmedTarget }) {
            onComplete()
        } else {
            isSubmitting = false
            errorMessage = "Failed to create cast"
        }
    }
}
