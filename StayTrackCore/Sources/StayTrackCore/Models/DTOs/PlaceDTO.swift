import Foundation

/// Objeto de transferencia de datos para Place.
public struct PlaceDTO: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var isFavorite: Bool
    public var category: PlaceCategory
    public var customCategoryName: String?
    public var icon: String
    public var latitude: Double
    public var longitude: Double
    public var radius: Double
    public var createdAt: Date
    public var updatedAt: Date

    public var coordinate: Coordinate {
        Coordinate(latitude: latitude, longitude: longitude)
    }

    public init(
        id: UUID = UUID(),
        name: String,
        isFavorite: Bool = false,
        category: PlaceCategory = .otro,
        customCategoryName: String? = nil,
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
        self.category = category
        self.customCategoryName = customCategoryName
        self.icon = icon ?? category.defaultIcon
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(from place: Place) {
        self.id = place.id
        self.name = place.name
        self.isFavorite = place.isFavorite
        self.category = place.category
        self.customCategoryName = place.customCategoryName
        self.icon = place.icon
        self.latitude = place.latitude
        self.longitude = place.longitude
        self.radius = place.radius
        self.createdAt = place.createdAt
        self.updatedAt = place.updatedAt
    }

    public func toModel() -> Place {
        Place(
            id: id,
            nombre: name,
            latitud: latitude,
            longitud: longitude,
            radio: radius,
            isFavorite: isFavorite,
            categoria: category,
            nombrePersonalizadoCategoria: customCategoryName,
            icono: icon,
            fechaCreacion: createdAt,
            fechaModificacion: updatedAt
        )
    }
}
