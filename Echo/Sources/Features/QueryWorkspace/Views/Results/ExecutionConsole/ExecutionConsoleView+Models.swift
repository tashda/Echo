import SwiftUI

extension ExecutionConsoleView {
    struct Message: Identifiable {
        struct Detail: Identifiable {
            let id = UUID()
            let key: String
            let value: String
            let highlight: Highlight

            enum Highlight {
                case normal
                case emphasis
                case warning

                var valueColor: Color {
                    switch self {
                    case .normal:
                        return ColorTokens.Text.primary
                    case .emphasis:
                        return ColorTokens.accent
                    case .warning:
                        return Color.orange
                    }
                }
            }
        }

        enum Severity: String, CaseIterable {
            case info, warning, error, debug

            var iconName: String {
                switch self {
                case .info: return "info.circle"
                case .warning: return "exclamationmark.triangle"
                case .error: return "xmark.octagon"
                case .debug: return "ladybug"
                }
            }

            func tint(using accent: Color) -> Color {
                switch self {
                case .info:
                    return accent
                case .warning:
                    return Color.orange
                case .error:
                    return ColorTokens.Status.error
                case .debug:
                    return ColorTokens.Text.secondary
                }
            }
        }

        let id = UUID()
        let sequence: Int
        let title: String
        let timestamp: Date
        let delta: TimeInterval
        let duration: TimeInterval?
        let procedure: String?
        let line: String?
        let severity: Severity
        let details: [Detail]
    }
}
