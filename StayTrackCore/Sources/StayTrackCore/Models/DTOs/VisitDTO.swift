import Foundation

/// Objeto de transferencia de datos para Visit, con soporte completo de codificación
/// para sincronización y exportación.
public struct VisitDTO: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var placeId: UUID?
    public var latitude: Double
    public var longitude: Double
    public var arrivalDate: Date
    public var departureDate: Date?
    public var deviceSource: DeviceSource
    public var isMovingDetected: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public var duration: TimeInterval {
        let end = departureDate ?? Date()
        return max(0, end.timeIntervalSince(arrivalDate))
    }

    public var isOngoing: Bool {
        return departureDate == nil
    }

    public init(
        id: UUID = UUID(),
        placeId: UUID? = nil,
        latitude: Double,
        longitude: Double,
        arrivalDate: Date = Date(),
        departureDate: Date? = nil,
        deviceSource: DeviceSource = .iphone,
        isMovingDetected: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.placeId = placeId
        self.latitude = latitude
        self.longitude = longitude
        self.arrivalDate = arrivalDate
        self.departureDate = departureDate
        self.deviceSource = deviceSource
        self.isMovingDetected = isMovingDetected
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(from visit: Visit) {
        self.id = visit.id
        self.placeId = visit.placeId ?? visit.place?.id
        self.latitude = visit.latitude
        self.longitude = visit.longitude
        self.arrivalDate = visit.arrivalDate
        self.departureDate = visit.departureDate
        self.deviceSource = visit.deviceSource
        self.isMovingDetected = visit.isMovingDetected
        self.createdAt = visit.createdAt
        self.updatedAt = visit.updatedAt
    }
}
