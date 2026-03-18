import SwiftUI

public enum TypographyTokens {
    public enum Weight {
        public static let regular = SwiftUI.Font.Weight.regular
        public static let medium = SwiftUI.Font.Weight.medium
        public static let semibold = SwiftUI.Font.Weight.semibold
        public static let bold = SwiftUI.Font.Weight.bold
    }

    // Semantic styles (dynamic type)
    public static let title = SwiftUI.Font.system(.title, design: .default)
    public static let title2 = SwiftUI.Font.system(.title2, design: .default)
    public static let title3 = SwiftUI.Font.system(.title3, design: .default)
    public static let headline = SwiftUI.Font.system(.headline, design: .default)
    public static let subheadline = SwiftUI.Font.system(.subheadline, design: .default)
    public static let body = SwiftUI.Font.system(.body, design: .default)
    public static let callout = SwiftUI.Font.system(.callout, design: .default)
    public static let caption = SwiftUI.Font.system(.caption, design: .default)
    public static let footnote = SwiftUI.Font.system(.footnote, design: .default)
    public static let monospaced = SwiftUI.Font.system(.body, design: .monospaced)

    // Fixed-size styles for macOS UI where precise sizing matters
    /// 9pt — toolbar badges, compact indicators
    public static let compact = SwiftUI.Font.system(size: 9)
    /// 10pt — sidebar counts, small labels
    public static let label = SwiftUI.Font.system(size: 10)
    /// 11pt — table cells, footnotes, secondary detail
    public static let detail = SwiftUI.Font.system(size: 11)
    
    /// 11pt Medium — Standard sidebar label matching macOS 26 Tahoe Figma
    public static let sidebarLabel = SwiftUI.Font.system(size: 11, weight: .medium)
    
    /// 12pt — secondary labels, form fields
    public static let caption2 = SwiftUI.Font.system(size: 12)
    /// 13pt Regular — primary UI text, body equivalent
    public static let standard = SwiftUI.Font.system(size: 13)
    /// 14pt — section headers, prominent labels
    public static let prominent = SwiftUI.Font.system(size: 14)
    
    // Tahoe Form Styles
    /// 13pt Bold — Form section headers matching System Settings (e.g. "Windows")
    public static let formSectionTitle = SwiftUI.Font.system(size: 13).weight(.bold)
    /// 13pt Regular — Primary label text in form rows
    public static let formLabel = SwiftUI.Font.system(size: 13)
    /// 13pt Regular — Primary value text in form rows (e.g. selected item in a Pop-up button)
    public static let formValue = SwiftUI.Font.system(size: 13)
    /// 11pt Regular — Secondary description or subtitle text in form rows
    public static let formDescription = SwiftUI.Font.system(size: 11)

    /// 12pt Bold — Legacy Form section headers (consider migrating to formSectionTitle)
    public static let formSectionHeader = SwiftUI.Font.system(size: 12).weight(.bold)

    /// 12pt Medium — Status badges and indicators
    public static let statusLabel = SwiftUI.Font.system(size: 12).weight(.medium)

    /// 16pt — large headers
    public static let display = SwiftUI.Font.system(size: 16)
    /// 18pt — large display headers
    public static let displayLarge = SwiftUI.Font.system(size: 18)
    /// 20pt+ — hero text, large icons
    public static let hero = SwiftUI.Font.system(size: 20)
}
