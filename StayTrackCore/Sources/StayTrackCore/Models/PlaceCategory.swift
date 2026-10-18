import Foundation

/// Categorías de lugares soportadas por StayTrack.
/// Cada categoría incluye su icono SF Symbol por defecto y colores característicos
/// acordes a la estética moderna / dark-mode de la aplicación.
public enum PlaceCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case home
    case work
    case workout
    case medical
    case other

    public var id: String { rawValue }

    /// Nombre amigable para mostrar en la interfaz de usuario
    public var displayName: String {
        switch self {
        case .home:
            return "Casa"
        case .work:
            return "Trabajo"
        case .workout:
            return "Entrenamiento"
        case .medical:
            return "Médico"
        case .other:
            return "Otro"
        }
    }

    /// Icono SF Symbol recomendado para la categoría
    public var defaultIcon: String {
        switch self {
        case .home:
            return "house.fill"
        case .work:
            return "briefcase.fill"
        case .workout:
            return "figure.run"
        case .medical:
            return "cross.case.fill"
        case .other:
            return "mappin.and.ellipse"
        }
    }

    /// Color hexadecimal para acentos y gráficos acordes al diseño futurista
    public var accentHex: String {
        switch self {
        case .home:
            return "#00E5FF" // Cian vibrante
        case .work:
            return "#7C4DFF" // Púrpura eléctrico
        case .workout:
            return "#FF5252" // Coral neón
        case .medical:
            return "#69F0AE" // Esmeralda brillante
        case .other:
            return "#FFD740" // Ámbar dorado
        }
    }
}
