import Foundation

/// A single parsed spatial geometry with its row index and WKT source.
struct SpatialGeometry: Identifiable, Sendable {
    let id: Int
    let rowIndex: Int
    let columnName: String
    let shape: SpatialShape
    let wkt: String
}

/// Parsed spatial shape variants.
enum SpatialShape: Sendable {
    case point(SpatialCoordinate)
    case multiPoint([SpatialCoordinate])
    case lineString([SpatialCoordinate])
    case multiLineString([[SpatialCoordinate]])
    case polygon([SpatialRing])
    case multiPolygon([[SpatialRing]])
    case geometryCollection([SpatialShape])
}

/// A single coordinate pair (x/y or lon/lat).
struct SpatialCoordinate: Sendable {
    let x: Double
    let y: Double
}

/// A closed ring of coordinates forming a polygon boundary.
struct SpatialRing: Sendable {
    let coordinates: [SpatialCoordinate]
}

/// Bounding box computed from all geometries.
struct SpatialBounds: Sendable {
    var minX: Double
    var minY: Double
    var maxX: Double
    var maxY: Double

    var width: Double { maxX - minX }
    var height: Double { maxY - minY }
    var centerX: Double { (minX + maxX) / 2 }
    var centerY: Double { (minY + maxY) / 2 }

    static let empty = SpatialBounds(minX: 0, minY: 0, maxX: 0, maxY: 0)

    mutating func extend(with coord: SpatialCoordinate) {
        minX = min(minX, coord.x)
        minY = min(minY, coord.y)
        maxX = max(maxX, coord.x)
        maxY = max(maxY, coord.y)
    }
}

// MARK: - WKT Parser

enum WKTParser {
    /// Parse a WKT string into a SpatialShape, returns nil if unrecognised.
    static func parse(_ wkt: String) -> SpatialShape? {
        let trimmed = wkt.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmed.hasPrefix("GEOMETRYCOLLECTION") {
            return parseGeometryCollection(wkt)
        } else if trimmed.hasPrefix("MULTIPOLYGON") {
            return parseMultiPolygon(wkt)
        } else if trimmed.hasPrefix("MULTILINESTRING") {
            return parseMultiLineString(wkt)
        } else if trimmed.hasPrefix("MULTIPOINT") {
            return parseMultiPoint(wkt)
        } else if trimmed.hasPrefix("POLYGON") {
            return parsePolygon(wkt)
        } else if trimmed.hasPrefix("LINESTRING") {
            return parseLineString(wkt)
        } else if trimmed.hasPrefix("POINT") {
            return parsePoint(wkt)
        }
        return nil
    }

    // MARK: - Individual Parsers

    private static func parsePoint(_ wkt: String) -> SpatialShape? {
        guard let content = extractContent(from: wkt, prefix: "POINT") else { return nil }
        let inner = content.trimmingCharacters(in: CharacterSet(charactersIn: "()"))
        guard let coord = parseCoordinate(inner) else { return nil }
        return .point(coord)
    }

    private static func parseMultiPoint(_ wkt: String) -> SpatialShape? {
        guard let content = extractContent(from: wkt, prefix: "MULTIPOINT") else { return nil }
        let coords = parseCoordinateList(content.trimmingCharacters(in: CharacterSet(charactersIn: "()")))
        guard !coords.isEmpty else { return nil }
        return .multiPoint(coords)
    }

    private static func parseLineString(_ wkt: String) -> SpatialShape? {
        guard let content = extractContent(from: wkt, prefix: "LINESTRING") else { return nil }
        let coords = parseCoordinateList(content.trimmingCharacters(in: CharacterSet(charactersIn: "()")))
        guard coords.count >= 2 else { return nil }
        return .lineString(coords)
    }

    private static func parseMultiLineString(_ wkt: String) -> SpatialShape? {
        guard let content = extractContent(from: wkt, prefix: "MULTILINESTRING") else { return nil }
        let rings = splitRings(content)
        let lines = rings.compactMap { parseCoordinateList($0) }.filter { $0.count >= 2 }
        guard !lines.isEmpty else { return nil }
        return .multiLineString(lines)
    }

    private static func parsePolygon(_ wkt: String) -> SpatialShape? {
        guard let content = extractContent(from: wkt, prefix: "POLYGON") else { return nil }
        let rings = splitRings(content).compactMap { ringStr -> SpatialRing? in
            let coords = parseCoordinateList(ringStr)
            guard coords.count >= 3 else { return nil }
            return SpatialRing(coordinates: coords)
        }
        guard !rings.isEmpty else { return nil }
        return .polygon(rings)
    }

    private static func parseMultiPolygon(_ wkt: String) -> SpatialShape? {
        guard let content = extractContent(from: wkt, prefix: "MULTIPOLYGON") else { return nil }
        let polygonGroups = splitTopLevelGroups(content)
        let polygons = polygonGroups.compactMap { group -> [SpatialRing]? in
            let rings = splitRings(group).compactMap { ringStr -> SpatialRing? in
                let coords = parseCoordinateList(ringStr)
                guard coords.count >= 3 else { return nil }
                return SpatialRing(coordinates: coords)
            }
            return rings.isEmpty ? nil : rings
        }
        guard !polygons.isEmpty else { return nil }
        return .multiPolygon(polygons)
    }

    private static func parseGeometryCollection(_ wkt: String) -> SpatialShape? {
        guard let content = extractContent(from: wkt, prefix: "GEOMETRYCOLLECTION") else { return nil }
        let parts = splitGeometryCollectionMembers(content)
        let shapes = parts.compactMap { parse($0) }
        guard !shapes.isEmpty else { return nil }
        return .geometryCollection(shapes)
    }

    // MARK: - Helpers

    private static func extractContent(from wkt: String, prefix: String) -> String? {
        let upper = wkt.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard upper.hasPrefix(prefix) else { return nil }
        let original = wkt.trimmingCharacters(in: .whitespacesAndNewlines)
        let afterPrefix = original.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
        guard afterPrefix.hasPrefix("("), afterPrefix.hasSuffix(")") else { return nil }
        return String(afterPrefix.dropFirst().dropLast())
    }

    private static func parseCoordinate(_ str: String) -> SpatialCoordinate? {
        let parts = str.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 2,
              let x = Double(parts[0]),
              let y = Double(parts[1]) else { return nil }
        return SpatialCoordinate(x: x, y: y)
    }

    private static func parseCoordinateList(_ str: String) -> [SpatialCoordinate] {
        str.split(separator: ",").compactMap { parseCoordinate(String($0)) }
    }

    /// Split "(ring1), (ring2)" into individual ring content strings.
    private static func splitRings(_ content: String) -> [String] {
        var results: [String] = []
        var depth = 0
        var current = ""
        for char in content {
            if char == "(" {
                depth += 1
                if depth == 1 { current = ""; continue }
            } else if char == ")" {
                depth -= 1
                if depth == 0 { results.append(current); continue }
            }
            if depth >= 1 { current.append(char) }
        }
        return results
    }

    /// Split top-level parenthesised groups: "((ring)), ((ring))" for multipolygon.
    private static func splitTopLevelGroups(_ content: String) -> [String] {
        var results: [String] = []
        var depth = 0
        var current = ""
        for char in content {
            if char == "(" {
                depth += 1
                if depth == 1 { current = ""; continue }
                current.append(char)
            } else if char == ")" {
                depth -= 1
                if depth == 0 { results.append(current); continue }
                current.append(char)
            } else if depth >= 1 {
                current.append(char)
            }
        }
        return results
    }

    /// Split geometry collection members by finding commas at depth 0.
    private static func splitGeometryCollectionMembers(_ content: String) -> [String] {
        var results: [String] = []
        var depth = 0
        var current = ""
        for char in content {
            if char == "(" { depth += 1 }
            else if char == ")" { depth -= 1 }
            if char == "," && depth == 0 {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { results.append(trimmed) }
                current = ""
            } else {
                current.append(char)
            }
        }
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { results.append(trimmed) }
        return results
    }
}

// MARK: - Bounds Calculation

extension SpatialShape {
    func extendBounds(_ bounds: inout SpatialBounds) {
        switch self {
        case .point(let coord):
            bounds.extend(with: coord)
        case .multiPoint(let coords):
            for coord in coords { bounds.extend(with: coord) }
        case .lineString(let coords):
            for coord in coords { bounds.extend(with: coord) }
        case .multiLineString(let lines):
            for line in lines { for coord in line { bounds.extend(with: coord) } }
        case .polygon(let rings):
            for ring in rings { for coord in ring.coordinates { bounds.extend(with: coord) } }
        case .multiPolygon(let polygons):
            for rings in polygons { for ring in rings { for coord in ring.coordinates { bounds.extend(with: coord) } } }
        case .geometryCollection(let shapes):
            for shape in shapes { shape.extendBounds(&bounds) }
        }
    }
}

// MARK: - Extraction from Query Results

enum SpatialExtractor {
    /// Spatial-relevant data type names (case-insensitive match).
    private static let spatialTypes: Set<String> = [
        "geometry", "geography", "point", "linestring", "polygon",
        "multipoint", "multilinestring", "multipolygon", "geometrycollection",
        "st_geometry", "sdo_geometry", "user-defined"
    ]

    /// Returns true if the given column data type is a spatial type.
    static func isSpatialColumn(_ dataType: String) -> Bool {
        spatialTypes.contains(dataType.lowercased())
    }

    /// Extract spatial geometries from query result rows.
    /// - Parameters:
    ///   - columns: The column definitions.
    ///   - rowCount: Number of rows available.
    ///   - rowAccessor: Closure that returns the cell value for a given (row, column) index.
    /// - Returns: Array of parsed spatial geometries.
    static func extract(
        columns: [ColumnInfo],
        rowCount: Int,
        rowAccessor: (Int, Int) -> String?
    ) -> [SpatialGeometry] {
        let spatialColumnIndices = columns.enumerated().compactMap { index, col -> (Int, String)? in
            // Check dataType first
            if isSpatialColumn(col.dataType) {
                return (index, col.name)
            }
            return nil
        }

        guard !spatialColumnIndices.isEmpty else {
            // Fallback: try parsing first few rows to detect WKT in any text column
            return extractByContentDetection(columns: columns, rowCount: rowCount, rowAccessor: rowAccessor)
        }

        var geometries: [SpatialGeometry] = []
        var nextID = 0
        let maxRows = min(rowCount, 1000)

        for rowIndex in 0..<maxRows {
            for (colIndex, colName) in spatialColumnIndices {
                guard let cellValue = rowAccessor(rowIndex, colIndex),
                      let shape = WKTParser.parse(cellValue) else { continue }
                geometries.append(SpatialGeometry(
                    id: nextID,
                    rowIndex: rowIndex,
                    columnName: colName,
                    shape: shape,
                    wkt: cellValue
                ))
                nextID += 1
            }
        }
        return geometries
    }

    /// Fallback: scan text columns for WKT patterns.
    private static func extractByContentDetection(
        columns: [ColumnInfo],
        rowCount: Int,
        rowAccessor: (Int, Int) -> String?
    ) -> [SpatialGeometry] {
        let textColumnIndices = columns.enumerated().compactMap { index, col -> (Int, String)? in
            let dt = col.dataType.lowercased()
            if dt.contains("text") || dt.contains("varchar") || dt.contains("char") || dt == "string" || dt == "user-defined" {
                return (index, col.name)
            }
            return nil
        }
        guard !textColumnIndices.isEmpty else { return [] }

        var geometries: [SpatialGeometry] = []
        var nextID = 0
        let sampleRows = min(rowCount, 1000)

        for rowIndex in 0..<sampleRows {
            for (colIndex, colName) in textColumnIndices {
                guard let cellValue = rowAccessor(rowIndex, colIndex),
                      looksLikeWKT(cellValue),
                      let shape = WKTParser.parse(cellValue) else { continue }
                geometries.append(SpatialGeometry(
                    id: nextID,
                    rowIndex: rowIndex,
                    columnName: colName,
                    shape: shape,
                    wkt: cellValue
                ))
                nextID += 1
            }
        }
        return geometries
    }

    private static func looksLikeWKT(_ value: String) -> Bool {
        let upper = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let prefixes = ["POINT", "LINESTRING", "POLYGON", "MULTIPOINT", "MULTILINESTRING", "MULTIPOLYGON", "GEOMETRYCOLLECTION"]
        return prefixes.contains(where: { upper.hasPrefix($0) })
    }
}
