import SwiftUI

public enum TypographyTokens {
    public enum Weight {
        public static let regular = SwiftUI.Font.Weight.regular
        public static let medium = SwiftUI.Font.Weight.medium
        public static let semibold = SwiftUI.Font.Weight.semibold
        public static let bold = SwiftUI.Font.Weight.bold
    }

    public static let title = SwiftUI.Font.system(.title, design: .default)
    public static let headline = SwiftUI.Font.system(.headline, design: .default)
    public static let subheadline = SwiftUI.Font.system(.subheadline, design: .default)
    public static let body = SwiftUI.Font.system(.body, design: .default)
    public static let callout = SwiftUI.Font.system(.callout, design: .default)
    public static let caption = SwiftUI.Font.system(.caption, design: .default)
    public static let footnote = SwiftUI.Font.system(.footnote, design: .default)
    public static let monospaced = SwiftUI.Font.system(.body, design: .monospaced)
}
