import SwiftUI

/// A standardized sheet chrome matching the macOS System Settings sheet pattern.
///
/// Provides: optional header (icon + title + subtitle), content area, and footer
/// with correct button styling, all on one surface: no hairline between the content
/// and the buttons, and no `.background(.bar)` (round 33.2, SE1). The primary button
/// is prominent while it can be pressed (PB1).
///
/// **Standard usage:**
/// ```swift
/// SheetLayout(
///     title: "New Trigger",
///     icon: "bolt",
///     subtitle: "Create a new server-scoped DDL trigger.",
///     primaryAction: "Create",
///     canSubmit: canCreate,
///     isSubmitting: isCreating,
///     errorMessage: errorMessage,
///     onSubmit: { await createTrigger() },
///     onCancel: { onDismiss() }
/// ) {
///     Form { ... }
///         .formStyle(.grouped)
///         .scrollContentBackground(.hidden)
/// }
/// .frame(minWidth: 480, idealWidth: 520, minHeight: 400)
/// ```
struct SheetLayout<Content: View>: View {
    let title: String
    let icon: String?
    let subtitle: String?
    let primaryAction: String
    let canSubmit: Bool
    let isSubmitting: Bool
    let errorMessage: String?
    let onSubmit: () async -> Void
    let onCancel: () -> Void
    let destructiveAction: String?
    let onDestructive: (() -> Void)?
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        icon: String? = nil,
        subtitle: String? = nil,
        primaryAction: String,
        canSubmit: Bool,
        isSubmitting: Bool = false,
        errorMessage: String? = nil,
        onSubmit: @escaping () async -> Void,
        onCancel: @escaping () -> Void,
        destructiveAction: String? = nil,
        onDestructive: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.subtitle = subtitle
        self.primaryAction = primaryAction
        self.canSubmit = canSubmit
        self.isSubmitting = isSubmitting
        self.errorMessage = errorMessage
        self.onSubmit = onSubmit
        self.onCancel = onCancel
        self.destructiveAction = destructiveAction
        self.onDestructive = onDestructive
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            if icon != nil || subtitle != nil {
                sheetHeader
            }

            content()

            HStack(spacing: SpacingTokens.sm) {
                if let destructiveAction, let onDestructive {
                    Button(destructiveAction, role: .destructive) { onDestructive() }
                        .buttonStyle(.bordered)
                        .tint(ColorTokens.Status.error)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Status.error)
                        .lineLimit(2)
                }

                Spacer()

                if isSubmitting {
                    ProgressView()
                        .controlSize(.small)
                }

                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)

                SheetLayout<EmptyView>.primaryButton(primaryAction, canSubmit: canSubmit) { Task { await onSubmit() } }
            }
            .padding(.horizontal, SpacingTokens.md2)
            .padding(.vertical, SpacingTokens.sm2)
        }
        .navigationTitle(title)
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack(spacing: SpacingTokens.sm) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor, in: .rect(cornerRadius: ShapeTokens.CornerRadius.medium))
            }

            VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
                Text(title)
                    .font(TypographyTokens.prominent.weight(.semibold))

                if let subtitle {
                    Text(subtitle)
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, SpacingTokens.lg)
        .padding(.top, SpacingTokens.md)
        .padding(.bottom, SpacingTokens.xs)
    }
}

extension SheetLayout where Content == EmptyView {
    /// The sheet's default button: prominent while it can be pressed, bordered and dimmed while not
    /// (VISUAL_GUIDELINES › Sheets). For custom footers too.
    @ViewBuilder
    static func primaryButton(_ title: String, canSubmit: Bool, action: @escaping () -> Void) -> some View {
        if canSubmit {
            Button(title, action: action)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        } else {
            Button(title, action: action)
                .buttonStyle(.bordered)
                .disabled(true)
                .keyboardShortcut(.defaultAction)
        }
    }
}

/// A variant of `SheetLayout` for wizards and multi-step flows where the
/// caller provides the entire footer content. One surface, no hairline (round 33.2, SE1);
/// use `SheetLayout.primaryButton` for the default button.
struct SheetLayoutCustomFooter<Content: View, Footer: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @ViewBuilder let footer: () -> Footer

    var body: some View {
        VStack(spacing: 0) {
            content()

            HStack(spacing: SpacingTokens.sm) {
                footer()
            }
            .padding(.horizontal, SpacingTokens.md2)
            .padding(.vertical, SpacingTokens.sm2)
        }
        .navigationTitle(title)
    }
}
