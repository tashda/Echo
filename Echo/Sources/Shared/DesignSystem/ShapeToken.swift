import SwiftUI

public enum ShapeTokens {
    public enum CornerRadius {
        /// 2pt — very small details
        public static let nano: CGFloat = 2
        /// 4pt — small buttons, thumbnails
        public static let extraSmall: CGFloat = 4
        /// 6pt — cards, standard buttons
        public static let small: CGFloat = 6
        /// 8pt — primary containers, editor blocks
        public static let medium: CGFloat = 8
        /// 12pt — large modals, popovers
        public static let large: CGFloat = 12
    }
}
