import Foundation

/// Builds external browser links for spatial point geometries.
enum SpatialBrowserLinkBuilder {
    static func menuItems(for geometries: [SpatialGeometry], limit: Int = 12) -> [SpatialBrowserMenuItem] {
        geometries
            .compactMap(menuItem(for:))
            .prefix(limit)
            .map { $0 }
    }

    static func menuItem(for geometry: SpatialGeometry) -> SpatialBrowserMenuItem? {
        guard let coordinate = browserCoordinate(for: geometry.shape),
              let url = browserURL(for: coordinate) else {
            return nil
        }

        return SpatialBrowserMenuItem(
            id: geometry.id,
            label: "Row \(geometry.rowIndex + 1): \(geometry.columnName)",
            coordinate: coordinate,
            url: url
        )
    }

    static func browserCoordinate(for shape: SpatialShape) -> SpatialCoordinate? {
        switch shape {
        case .point(let coordinate):
            return isBrowserCoordinate(coordinate) ? coordinate : nil
        case .multiPoint(let coordinates):
            guard coordinates.count == 1 else { return nil }
            return isBrowserCoordinate(coordinates[0]) ? coordinates[0] : nil
        case .geometryCollection(let shapes):
            for shape in shapes {
                if let coordinate = browserCoordinate(for: shape) {
                    return coordinate
                }
            }
            return nil
        case .lineString, .multiLineString, .polygon, .multiPolygon:
            return nil
        }
    }

    static func browserURL(for coordinate: SpatialCoordinate) -> URL? {
        guard isBrowserCoordinate(coordinate) else { return nil }

        var components = URLComponents(string: "https://www.openstreetmap.org/")
        components?.queryItems = [
            URLQueryItem(name: "mlat", value: browserCoordinateString(coordinate.y)),
            URLQueryItem(name: "mlon", value: browserCoordinateString(coordinate.x)),
            URLQueryItem(name: "zoom", value: "15"),
        ]
        return components?.url
    }

    private static func isBrowserCoordinate(_ coordinate: SpatialCoordinate) -> Bool {
        coordinate.x >= -180 && coordinate.x <= 180 &&
        coordinate.y >= -90 && coordinate.y <= 90
    }

    private static func browserCoordinateString(_ value: Double) -> String {
        let roundedValue = (value * 1_000_000).rounded() / 1_000_000
        return roundedValue.formatted(
            .number
            .precision(.fractionLength(0...6))
            .locale(Locale(identifier: "en_US_POSIX"))
        )
    }
}

struct SpatialBrowserMenuItem: Identifiable, Sendable, Equatable {
    let id: Int
    let label: String
    let coordinate: SpatialCoordinate
    let url: URL
}
