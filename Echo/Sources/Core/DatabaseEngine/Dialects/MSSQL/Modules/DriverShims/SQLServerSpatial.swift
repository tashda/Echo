import SQLServerKit
import Foundation
import NIOCore

/// A spatial geometry or geography object from SQL Server.
/// Decodes the [MS-SSCLRSPS] binary serialization format.
public struct SQLServerSpatial: Sendable, Equatable {
    public enum ShapeType: UInt8, Sendable {
        case point = 1
        case lineString = 2
        case polygon = 3
        case multiPoint = 4
        case multiLineString = 5
        case multiPolygon = 6
        case geometryCollection = 7
        case circularString = 8
        case compoundCurve = 9
        case curvePolygon = 10
        case fullGlobe = 11
    }

    public struct Point: Sendable, Equatable {
        public let x: Double
        public let y: Double
        public let z: Double?
        public let m: Double?
        
        public init(x: Double, y: Double, z: Double? = nil, m: Double? = nil) {
            self.x = x
            self.y = y
            self.z = z
            self.m = m
        }
    }

    /// Spatial Reference ID (SRID).
    public let srid: Int32
    /// The geometric shape type.
    public let type: ShapeType
    /// All points in the object.
    public let points: [Point]
    
    /// Parses a SQL Server [MS-SSCLRSPS] binary payload.
    public static func decode(from buffer: inout ByteBuffer) -> SQLServerSpatial? {
        guard buffer.readableBytes >= 6 else { return nil }
        
        let srid = buffer.readInteger(endianness: .little, as: Int32.self) ?? 0
        guard let version = buffer.readInteger(as: UInt8.self), version == 1 || version == 2 else {
            return nil
        }
        
        guard let serializationProps = buffer.readInteger(as: UInt8.self) else { return nil }
        
        let hasZ = (serializationProps & 0x01) != 0
        let hasM = (serializationProps & 0x02) != 0
        let isValid = (serializationProps & 0x04) != 0
        let isSinglePoint = (serializationProps & 0x08) != 0
        let isSingleLineSegment = (serializationProps & 0x10) != 0
        let isWholeGlobe = (serializationProps & 0x20) != 0
        
        if isWholeGlobe {
            return SQLServerSpatial(srid: srid, type: .fullGlobe, points: [])
        }
        
        if isSinglePoint {
            guard let xInt = buffer.readInteger(endianness: .little, as: UInt64.self),
                  let yInt = buffer.readInteger(endianness: .little, as: UInt64.self) else { return nil }
            let x = Double(bitPattern: xInt)
            let y = Double(bitPattern: yInt)
            return SQLServerSpatial(srid: srid, type: .point, points: [Point(x: x, y: y)])
        }
        
        // Complex shapes
        guard let numberOfPoints = buffer.readInteger(endianness: .little, as: Int32.self) else { return nil }
        var points: [Point] = []
        for _ in 0..<numberOfPoints {
            guard let xInt = buffer.readInteger(endianness: .little, as: UInt64.self),
                  let yInt = buffer.readInteger(endianness: .little, as: UInt64.self) else { break }
            let x = Double(bitPattern: xInt)
            let y = Double(bitPattern: yInt)
            points.append(Point(x: x, y: y))
        }
        
        // Skip Z/M values for now to avoid over-complicating (but they are there if hasZ/hasM)
        
        guard let numberOfFigures = buffer.readInteger(endianness: .little, as: Int32.self) else {
            return SQLServerSpatial(srid: srid, type: .point, points: points)
        }
        
        // Read figures to determine type
        if numberOfFigures > 0 {
            _ = buffer.readInteger(as: UInt8.self) // Skip first attribute
            _ = buffer.readInteger(endianness: .little, as: Int32.self) // Skip point offset
        }
        
        guard let numberOfShapes = buffer.readInteger(endianness: .little, as: Int32.self), numberOfShapes > 0 else {
            return SQLServerSpatial(srid: srid, type: .point, points: points)
        }
        
        _ = buffer.readInteger(endianness: .little, as: Int32.self) // Skip parent offset
        _ = buffer.readInteger(endianness: .little, as: Int32.self) // Skip figure offset
        guard let typeByte = buffer.readInteger(as: UInt8.self),
              let type = ShapeType(rawValue: typeByte) else {
            return SQLServerSpatial(srid: srid, type: .point, points: points)
        }
        
        return SQLServerSpatial(srid: srid, type: type, points: points)
    }

    /// Returns the Well-Known Text (WKT) representation (e.g., "POINT(10 20)").
    public var wkt: String {
        switch type {
        case .point:
            guard let p = points.first else { return "POINT EMPTY" }
            return "POINT(\(format(p.x)) \(format(p.y)))"
        case .lineString:
            let pts = points.map { "\(format($0.x)) \(format($0.y))" }.joined(separator: ", ")
            return "LINESTRING(\(pts))"
        case .polygon:
            let pts = points.map { "\(format($0.x)) \(format($0.y))" }.joined(separator: ", ")
            return "POLYGON((\(pts)))"
        case .fullGlobe:
            return "FULLGLOBE"
        default:
            return "\(type.description.uppercased())(\(points.count) points)"
        }
    }
    
    private func format(_ value: Double) -> String {
        let s = String(format: "%.8f", value)
        if s.contains(".") {
            return s.replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "\\.$", with: "", options: .regularExpression)
        }
        return s
    }
}

extension SQLServerSpatial.ShapeType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .point: return "Point"
        case .lineString: return "LineString"
        case .polygon: return "Polygon"
        case .multiPoint: return "MultiPoint"
        case .multiLineString: return "MultiLineString"
        case .multiPolygon: return "MultiPolygon"
        case .geometryCollection: return "GeometryCollection"
        case .circularString: return "CircularString"
        case .compoundCurve: return "CompoundCurve"
        case .curvePolygon: return "CurvePolygon"
        case .fullGlobe: return "FullGlobe"
        }
    }
}
