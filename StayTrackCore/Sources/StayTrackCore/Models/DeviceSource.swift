import Foundation

/// Origen del dispositivo que registró una visita o lectura.
/// Según las reglas de dominio, el Apple Watch tiene prioridad de registro
/// sobre el iPhone cuando ambos dispositivos están en uso.
public enum DeviceSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case watch = "watch"
    case iphone = "iphone"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .watch:
            return "Apple Watch"
        case .iphone:
            return "iPhone"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .watch:
            return "applewatch"
        case .iphone:
            return "iphone"
        }
    }
}
