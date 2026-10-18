import Foundation
import SwiftData

/// Representa una estancia de tiempo registrada en un punto o lugar.
/// Conforme a los requisitos de SwiftData para StayTrack:
/// - id (UUID), placeId, inicio, fin (opcional si está activa),
///   origen (enum: watch, phone), coordenada ancla, precisión.
@Model
public final class Visit: Identifiable {
    public var id: UUID = UUID()
    public var placeId: UUID?
    public var inicio: Date = Date()
    public var fin: Date? = nil
    public var origenRaw: String = DeviceSource.phone.rawValue
    public var latitudAncla: Double = 0.0
    public var longitudAncla: Double = 0.0
    public var precision: Double = 0.0
    public var fechaModificacion: Date = Date()

    public var place: Place?

    public var origen: DeviceSource {
        get {
            DeviceSource(rawValue: origenRaw) ?? .phone
        }
        set {
            origenRaw = newValue.rawValue
        }
    }

    public var coordenadaAncla: Coordinate {
        get { Coordinate(latitude: latitudAncla, longitude: longitudAncla) }
        set {
            latitudAncla = newValue.latitude
            longitudAncla = newValue.longitude
        }
    }

    // MARK: - Propiedades de conveniencia en inglés
    public var startDate: Date {
        get { inicio }
        set { inicio = newValue }
    }
    public var endDate: Date? {
        get { fin }
        set { fin = newValue }
    }
    public var source: DeviceSource {
        get { origen }
        set { origen = newValue }
    }
    public var anchorCoordinate: Coordinate {
        get { coordenadaAncla }
        set { coordenadaAncla = newValue }
    }
    public var accuracy: Double {
        get { precision }
        set { precision = newValue }
    }

    /// Duración total en segundos (o acumulada hasta ahora si sigue activa)
    public var duration: TimeInterval {
        let finalDate = fin ?? Date()
        return max(0, finalDate.timeIntervalSince(inicio))
    }

    /// Indica si la visita está activa actualmente
    public var isOngoing: Bool {
        return fin == nil
    }

    public init(
        id: UUID = UUID(),
        placeId: UUID? = nil,
        place: Place? = nil,
        inicio: Date = Date(),
        fin: Date? = nil,
        origen: DeviceSource = .phone,
        coordenadaAncla: Coordinate,
        precision: Double = 10.0,
        fechaModificacion: Date = Date()
    ) {
        self.id = id
        self.placeId = placeId ?? place?.id
        self.place = place
        self.inicio = inicio
        self.fin = fin
        self.origenRaw = origen.rawValue
        self.latitudAncla = coordenadaAncla.latitude
        self.longitudAncla = coordenadaAncla.longitude
        self.precision = precision
        self.fechaModificacion = fechaModificacion
    }

    // Inicializador de conveniencia con parámetros en inglés / coordenadas individuales
    public convenience init(
        id: UUID = UUID(),
        placeId: UUID? = nil,
        place: Place? = nil,
        startDate: Date = Date(),
        endDate: Date? = nil,
        source: DeviceSource = .phone,
        latitude: Double,
        longitude: Double,
        accuracy: Double = 10.0,
        updatedAt: Date = Date()
    ) {
        self.init(
            id: id,
            placeId: placeId,
            place: place,
            inicio: startDate,
            fin: endDate,
            origen: source,
            coordenadaAncla: Coordinate(latitude: latitude, longitude: longitude),
            precision: accuracy,
            fechaModificacion: updatedAt
        )
    }
}
