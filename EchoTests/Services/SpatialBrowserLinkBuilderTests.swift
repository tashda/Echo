import Foundation
import Testing
@testable import Echo

@Suite("SpatialBrowserLinkBuilder")
struct SpatialBrowserLinkBuilderTests {
    @Test func pointProducesOpenStreetMapURL() throws {
        let coordinate = SpatialCoordinate(x: 12.568337, y: 55.676098)

        let url = try #require(SpatialBrowserLinkBuilder.browserURL(for: coordinate))

        #expect(url.absoluteString == "https://www.openstreetmap.org/?mlat=55.676098&mlon=12.568337&zoom=15")
    }

    @Test func invalidCoordinateDoesNotProduceBrowserURL() {
        let coordinate = SpatialCoordinate(x: 12.568337, y: 155.676098)

        let url = SpatialBrowserLinkBuilder.browserURL(for: coordinate)

        #expect(url == nil)
    }

    @Test func geometryCollectionFindsNestedPoint() {
        let shape = SpatialShape.geometryCollection([
            .lineString([SpatialCoordinate(x: 0, y: 0), SpatialCoordinate(x: 1, y: 1)]),
            .point(SpatialCoordinate(x: 12.568337, y: 55.676098)),
        ])

        let coordinate = SpatialBrowserLinkBuilder.browserCoordinate(for: shape)

        #expect(coordinate == SpatialCoordinate(x: 12.568337, y: 55.676098))
    }

    @Test func multiPointRequiresSingleCoordinate() {
        let shape = SpatialShape.multiPoint([
            SpatialCoordinate(x: 12.5, y: 55.6),
            SpatialCoordinate(x: 13.5, y: 56.6),
        ])

        let coordinate = SpatialBrowserLinkBuilder.browserCoordinate(for: shape)

        #expect(coordinate == nil)
    }

    @Test func menuItemsAreBuiltForBrowserOpenableGeometries() {
        let geometries = [
            SpatialGeometry(
                id: 1,
                rowIndex: 0,
                columnName: "pickup_point",
                shape: .point(SpatialCoordinate(x: 12.568337, y: 55.676098)),
                wkt: "POINT(12.568337 55.676098)"
            ),
            SpatialGeometry(
                id: 2,
                rowIndex: 1,
                columnName: "route_line",
                shape: .lineString([SpatialCoordinate(x: 0, y: 0), SpatialCoordinate(x: 1, y: 1)]),
                wkt: "LINESTRING(0 0, 1 1)"
            ),
        ]

        let items = SpatialBrowserLinkBuilder.menuItems(for: geometries)

        #expect(items.count == 1)
        #expect(items.first?.label == "Row 1: pickup_point")
        #expect(items.first?.url.absoluteString == "https://www.openstreetmap.org/?mlat=55.676098&mlon=12.568337&zoom=15")
    }
}
