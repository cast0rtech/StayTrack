import Foundation
import SwiftData

/// Muestra de movimiento registrada por un dispositivo.
/// Conforme a los requisitos de SwiftData para StayTrack:
/// - MovementSample: id, dispositivo (watch/phone), inicio, fin.
@Model
public final class MovementSample: Identifiable {
    public var id: UUID = UUID()
    public var dispositivoRaw: String = DeviceSource.watch.rawValue
    public var inicio: Date = Date()
    public var fin: Date = Date()

    public var dispositivo: DeviceSource {
        get {
            DeviceSource(rawValue: dispositivoRaw) ?? .watch
        }
        set {
            dispositivoRaw = newValue.rawValue
        }
    }

    // MARK: - Propiedades de conveniencia en inglés
    public var device: DeviceSource {
        get { dispositivo }
        set { dispositivo = newValue }
    }
    public var startDate: Date {
        get { inicio }
        set { inicio = newValue }
    }
    public var endDate: Date {
        get { fin }
        set { fin = newValue }
    }

    public var duration: TimeInterval {
        max(0, fin.timeIntervalSince(inicio))
    }

    public init(
        id: UUID = UUID(),
        dispositivo: DeviceSource = .watch,
        inicio: Date,
        fin: Date
    ) {
        self.id = id
        self.dispositivoRaw = dispositivo.rawValue
        self.inicio = inicio
        self.fin = fin
    }

    public convenience init(
        id: UUID = UUID(),
        device: DeviceSource = .watch,
        startDate: Date,
        endDate: Date
    ) {
        self.init(id: id, dispositivo: device, inicio: startDate, fin: endDate)
    }
}
