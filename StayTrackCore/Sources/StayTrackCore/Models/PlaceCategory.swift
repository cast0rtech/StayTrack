import Foundation

/// Categoría de lugar según las reglas de dominio de StayTrack:
/// (enum: casa, trabajo, entrenamiento, médico, otro).
public enum PlaceCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case casa
    case trabajo
    case entrenamiento
    case medico
    case otro

    public var id: String { rawValue }

    /// Nombre en español para mostrar en la interfaz de usuario
    public var displayName: String {
        switch self {
        case .casa:
            return "Casa"
        case .trabajo:
            return "Trabajo"
        case .entrenamiento:
            return "Entrenamiento"
        case .medico:
            return "Médico"
        case .otro:
            return "Otro"
        }
    }

    /// Icono SF Symbol recomendado por defecto para cada categoría
    public var defaultIcon: String {
        switch self {
        case .casa:
            return "house.fill"
        case .trabajo:
            return "briefcase.fill"
        case .entrenamiento:
            return "figure.run"
        case .medico:
            return "cross.case.fill"
        case .otro:
            return "mappin.and.ellipse"
        }
    }

    /// Color hexadecimal para acentos y gráficos modernos
    public var accentHex: String {
        switch self {
        case .casa:
            return "#00E5FF" // Cian vibrante
        case .trabajo:
            return "#7C4DFF" // Púrpura eléctrico
        case .entrenamiento:
            return "#FF5252" // Coral neón
        case .medico:
            return "#69F0AE" // Esmeralda brillante
        case .otro:
            return "#FFD740" // Ámbar dorado
        }
    }
}

#if canImport(SwiftUI)
import SwiftUI

extension PlaceCategory {
    /// Color SwiftUI correspondiente para la interfaz de usuario
    public var accentColor: Color {
        switch self {
        case .casa:
            return .cyan
        case .trabajo:
            return .purple
        case .entrenamiento:
            return .orange
        case .medico:
            return .green
        case .otro:
            return .yellow
        }
    }
}
#endif
