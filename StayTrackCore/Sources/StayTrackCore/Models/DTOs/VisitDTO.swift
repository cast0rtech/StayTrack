import Foundation

/// Objeto de transferencia de datos para Visit.
public struct VisitDTO: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var placeId: UUID?
    public var startDate: Date
    public var endDate: Date?
    public var source: DeviceSource
    public var anchorCoordinate: Coordinate
    public var accuracy: Double
    public var updatedAt: Date

    // Alias en español
    public var inicio: Date {
        get { startDate }
        set { startDate = newValue }
    }
    public var fin: Date? {
        get { endDate }
        set { endDate = newValue }
    }
    public var origen: DeviceSource {
        get { source }
        set { source = newValue }
    }
    public var precision: Double {
        get { accuracy }
        set { accuracy = newValue }
    }
    public var coordenadaAncla: Coordinate {
        get { anchorCoordinate }
        set { anchorCoordinate = newValue }
    }
    public var latitude: Double {
        anchorCoordinate.latitude
    }
    public var longitude: Double {
        anchorCoordinate.longitude
    }

    public var duration: TimeInterval {
        let finalDate = endDate ?? Date()
        return max(0, finalDate.timeIntervalSince(startDate))
    }

    public var isOngoing: Bool {
        endDate == nil
    }

    public init(
        id: UUID = UUID(),
        placeId: UUID? = nil,
        startDate: Date = Date(),
        endDate: Date? = nil,
        source: DeviceSource = .phone,
        anchorCoordinate: Coordinate,
        accuracy: Double = 10.0,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.placeId = placeId
        self.startDate = startDate
        self.endDate = endDate
        self.source = source
        self.anchorCoordinate = anchorCoordinate
        self.accuracy = accuracy
        self.updatedAt = updatedAt
    }

    public init(
        id: UUID = UUID(),
        placeId: UUID? = nil,
        latitude: Double,
        longitude: Double,
        arrivalDate: Date = Date(),
        departureDate: Date? = nil,
        deviceSource: DeviceSource = .phone,
        accuracy: Double = 10.0,
        updatedAt: Date = Date()
    ) {
        self.init(
            id: id,
            placeId: placeId,
            startDate: arrivalDate,
            endDate: departureDate,
            source: deviceSource,
            anchorCoordinate: Coordinate(latitude: latitude, longitude: longitude),
            accuracy: accuracy,
            updatedAt: updatedAt
        )
    }

    public init(from visit: Visit) {
        self.id = visit.id
        self.placeId = visit.placeId
        self.startDate = visit.inicio
        self.endDate = visit.fin
        self.source = visit.origen
        self.anchorCoordinate = visit.coordenadaAncla
        self.accuracy = visit.precision
        self.updatedAt = visit.fechaModificacion
    }

    public func toModel() -> Visit {
        Visit(
            id: id,
            placeId: placeId,
            inicio: startDate,
            fin: endDate,
            origen: source,
            coordenadaAncla: anchorCoordinate,
            precision: accuracy,
            fechaModificacion: updatedAt
        )
    }
}
