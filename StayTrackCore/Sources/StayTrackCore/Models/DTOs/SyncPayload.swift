import Foundation

/// Paquete de datos transmitido entre Apple Watch e iPhone mediante WatchConnectivity.
/// Contiene colecciones de Places y Visits con identificadores UUID estables.
public struct SyncPayload: Codable, Sendable {
    public var places: [PlaceDTO]
    public var visits: [VisitDTO]
    public var movementSamples: [MovementSampleDTO]
    public var source: DeviceSource
    public var sentAt: Date

    public init(
        places: [PlaceDTO] = [],
        visits: [VisitDTO] = [],
        movementSamples: [MovementSampleDTO] = [],
        source: DeviceSource,
        sentAt: Date = Date()
    ) {
        self.places = places
        self.visits = visits
        self.movementSamples = movementSamples
        self.source = source
        self.sentAt = sentAt
    }

    /// Serializa el payload a datos JSON binarios
    public func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    /// Deserializa el payload desde datos JSON
    public static func decode(from data: Data) throws -> SyncPayload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SyncPayload.self, from: data)
    }

    /// Convierte el payload a diccionario compatible con WCSession transferUserInfo
    public func toUserInfoDictionary() throws -> [String: Any] {
        let data = try encode()
        return ["sync_payload_data": data]
    }

    /// Extrae el payload de un diccionario de WCSession
    public static func fromUserInfoDictionary(_ dict: [String: Any]) throws -> SyncPayload? {
        guard let data = dict["sync_payload_data"] as? Data else {
            return nil
        }
        return try decode(from: data)
    }
}
