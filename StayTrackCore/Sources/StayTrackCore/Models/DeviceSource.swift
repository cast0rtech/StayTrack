import Foundation

/// Origen del dispositivo que registró una estancia o muestra de movimiento.
/// Según las reglas de dominio, el Apple Watch ('watch') tiene prioridad
/// sobre el iPhone ('phone').
public enum DeviceSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case watch
    case phone

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .watch:
            return "Apple Watch"
        case .phone:
            return "iPhone"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .watch:
            return "applewatch"
        case .phone:
            return "iphone"
        }
    }
}
