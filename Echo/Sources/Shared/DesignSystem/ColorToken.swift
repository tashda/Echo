import SwiftUI

public enum ColorTokens {
    // Brand / App Accent
    public static let accent = Color.accentColor
    
    // Backgrounds
    public enum Background {
        public static let primary = Color(nsColor: .windowBackgroundColor)
        public static let secondary = Color(nsColor: .controlBackgroundColor)
        public static let tertiary = Color(nsColor: .textBackgroundColor)
        public static let elevated = Color(nsColor: .underPageBackgroundColor)
    }
    
    // Text
    public enum Text {
        public static let primary = Color.primary
        public static let secondary = Color.secondary
        public static let tertiary = Color(nsColor: .tertiaryLabelColor)
        public static let quaternary = Color(nsColor: .quaternaryLabelColor)
        public static let placeholder = Color(nsColor: .placeholderTextColor)
    }
    
    // Dividers / Borders
    public enum Separator {
        public static let primary = Color(nsColor: .separatorColor)
        public static let secondary = Color(nsColor: .gridColor)
    }
    
    // Status
    public enum Status {
        public static let success = Color.green
        public static let warning = Color.orange
        public static let error = Color.red
        public static let info = Color.blue
    }

    // Tab Strip
    public enum TabStrip {
        // Background fills (standard, non-themed)
        public enum Background {
            public static let dark = Color(white: 0.22)
            public static let light = Color(white: 0.90)
        }

        // Active tab gradient stops
        public enum ActiveTab {
            public enum Dark {
                public static let top = Color.white.opacity(0.26)
                public static let bottom = Color.white.opacity(0.18)
                public static let hoverTop = Color.white.opacity(0.32)
                public static let hoverBottom = Color.white.opacity(0.24)
            }
            public enum Light {
                public static let top = Color(white: 0.99)
                public static let bottom = Color(white: 0.95)
                public static let hoverTop = Color(white: 1.0)
                public static let hoverBottom = Color(white: 0.97)
            }
        }

        // Inactive tab hover gradient stops
        public enum InactiveHover {
            public enum Dark {
                public static let top = Color.white.opacity(0.18)
                public static let bottom = Color.white.opacity(0.12)
            }
            public enum Light {
                public static let top = Color(white: 0.94)
                public static let bottom = Color(white: 0.90)
            }
        }

        // Drop target gradient stops
        public enum DropTarget {
            public enum Dark {
                public static let top = Color.white.opacity(0.24)
                public static let bottom = Color.white.opacity(0.18)
            }
            public enum Light {
                public static let top = Color(white: 0.90)
                public static let bottom = Color(white: 0.86)
            }
        }

        // Tab borders
        public enum Border {
            public static let activeDark = Color.white.opacity(0.30)
            public static let activeLight = Color(white: 0.86)
            public static let hoverDark = Color.white.opacity(0.22)
            public static let hoverLight = Color.white.opacity(0.68)
            public static let dropDark = Color.white.opacity(0.15)
            public static let dropLight = Color.black.opacity(0.05)
            public static let inactive = Color.black.opacity(0.1)
        }

        // Tab shadow
        public enum Shadow {
            public static let dark = Color.black.opacity(0.28)
            public static let light = Color.black.opacity(0.10)
        }

        // Hover highlight
        public enum Highlight {
            public static let dark = Color.white.opacity(0.38)
            public static let light = Color.white.opacity(0.55)
        }

        // Separator gradient stops
        public enum Separator {
            public enum Dark {
                public static let top = Color.white.opacity(0.28)
                public static let bottom = Color.white.opacity(0.16)
            }
            public enum Light {
                public static let top = Color(white: 0.88)
                public static let bottom = Color(white: 0.75)
            }
        }

        // Safari-style overlay
        public enum SafariBar {
            public static let gradientTop = Color.white.opacity(0.16)
            public static let gradientBottom = Color.black.opacity(0.14)
            public static let topEdge = Color.white.opacity(0.45)
        }
    }

    // Glow frame decorative palette
    public enum Glow {
        public static let violet = Color(red: 0.737, green: 0.510, blue: 0.953)
        public static let pink = Color(red: 0.961, green: 0.725, blue: 0.918)
        public static let periwinkle = Color(red: 0.553, green: 0.624, blue: 1.0)
        public static let coral = Color(red: 1.0, green: 0.404, blue: 0.471)
        public static let peach = Color(red: 1.0, green: 0.729, blue: 0.443)
        public static let lavender = Color(red: 0.776, green: 0.525, blue: 1.0)
    }

    // Explorer / Object Browser
    public enum Explorer {
        public static let database = Color.green
        public static let tables = Color.teal
        public static let views = Color.indigo
        public static let functions = Color.orange
        public static let jobs = Color.blue
        public static let security = Color.gray
        public static let extensions = Color.orange
        public static let linkedServers = Color.purple
    }
}
