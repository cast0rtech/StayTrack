import Foundation

/// Coordenada geográfica pura, independiente de CoreLocation.
/// Permite cálculo de distancias geodésicas y lógica de detección
/// 100% testeable y portable en cualquier plataforma.
public struct Coordinate: Equatable, Hashable, Codable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Calcula la distancia geodésica en metros hasta otra coordenada
    /// utilizando la fórmula de Haversine.
    public func distance(to other: Coordinate) -> Double {
        let earthRadiusMeters = 6371000.0

        let lat1Rad = latitude * .pi / 180.0
        let lon1Rad = longitude * .pi / 180.0
        let lat2Rad = other.latitude * .pi / 180.0
        let lon2Rad = other.longitude * .pi / 180.0

        let deltaLat = lat2Rad - lat1Rad
        let deltaLon = lon2Rad - lon1Rad

        let a = sin(deltaLat / 2.0) * sin(deltaLat / 2.0) +
                cos(lat1Rad) * cos(lat2Rad) *
                sin(deltaLon / 2.0) * sin(deltaLon / 2.0)

        let c = 2.0 * atan2(sqrt(a), sqrt(1.0 - a))
        return earthRadiusMeters * c
    }

    public static func == (lhs: Coordinate, rhs: Coordinate) -> Bool {
        return abs(lhs.latitude - rhs.latitude) < 0.000001 &&
               abs(lhs.longitude - rhs.longitude) < 0.000001
    }
}
