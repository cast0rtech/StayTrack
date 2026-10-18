import Foundation
import SwiftData

/// Representa un lugar físico agrupado por proximidad.
/// Puede ser marcado como favorito, categorizado y personalizado con un icono SF Symbol.
/// Los favoritos tienen prioridad sobre lugares genéricos o sin nombre al asignar una estancia.
@Model
public final class Place {
    public var id: UUID = UUID()
    public var name: String = ""
    public var isFavorite: Bool = false
    public var categoryRaw: String = PlaceCategory.other.rawValue
    public var icon: String = "mappin.and.ellipse"
    public var latitude: Double = 0.0
    public var longitude: Double = 0.0
    /// Radio de detección en metros (50 m, 75 m por defecto, o 100 m)
    public var radius: Double = 75.0
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \Visit.place)
    public var visits: [Visit]? = []

    public var category: PlaceCategory {
        get {
            PlaceCategory(rawValue: categoryRaw) ?? .other
        }
        set {
            categoryRaw = newValue.rawValue
        }
    }

    public init(
        id: UUID = UUID(),
        name: String,
        isFavorite: Bool = false,
        category: PlaceCategory = .other,
        icon: String? = nil,
        latitude: Double,
        longitude: Double,
        radius: Double = 75.0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.isFavorite = isFavorite
        self.categoryRaw = category.rawValue
        self.icon = icon ?? category.defaultIcon
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.visits = []
    }
}
