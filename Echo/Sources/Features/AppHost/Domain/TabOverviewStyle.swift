import Foundation

enum TabOverviewStyle: String, Codable, CaseIterable, Hashable {
    case comfortable
    case compact

    var displayName: String {
        switch self {
        case .comfortable:
            return "Comfortable"
        case .compact:
            return "Compact"
        }
    }

    var detail: String {
        switch self {
        case .comfortable:
            return "Spacious cards with rich previews."
        case .compact:
            return "Dense tiles that fit more tabs."
        }
    }
}
