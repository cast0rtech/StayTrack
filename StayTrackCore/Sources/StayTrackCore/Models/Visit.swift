import Foundation
import SwiftData

/// Representa una estancia de tiempo registrada en un punto o lugar.
/// Se crea cuando el usuario permanece más de 2 minutos dentro del radio de detección
/// desde el punto ancla.
@Model
public final class Visit {
    public var id: UUID = UUID()
    public var placeId: UUID?
    public var latitude: Double = 0.0
    public var longitude: Double = 0.0
    public var arrivalDate: Date = Date()
    public var departureDate: Date?
    public var deviceSourceRaw: String = DeviceSource.iphone.rawValue
    /// Indica si durante la estancia se detectó movimiento (útil para desempate contra dispositivos estáticos)
    public var isMovingDetected: Bool = false
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public var place: Place?

    public var deviceSource: DeviceSource {
        get {
            DeviceSource(rawValue: deviceSourceRaw) ?? .iphone
        }
        set {
            deviceSourceRaw = newValue.rawValue
        }
    }

    /// Duración total en segundos (o acumulada hasta el momento presente si sigue activa)
    public var duration: TimeInterval {
        let end = departureDate ?? Date()
        return max(0, end.timeIntervalSince(arrivalDate))
    }

    /// Indica si la visita está todavía en curso (sin fecha de salida)
    public var isOngoing: Bool {
        return departureDate == nil
    }

    public init(
        id: UUID = UUID(),
        placeId: UUID? = nil,
        place: Place? = nil,
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
        self.placeId = placeId ?? place?.id
        self.place = place
        self.latitude = latitude
        self.longitude = longitude
        self.arrivalDate = arrivalDate
        self.departureDate = departureDate
        self.deviceSourceRaw = deviceSource.rawValue
        self.isMovingDetected = isMovingDetected
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
