import Foundation
import SwiftData

/// Representa un lugar físico agrupado por proximidad.
/// Conforme a los requisitos de SwiftData para StayTrack:
/// - id (UUID), nombre, latitud, longitud, radio (metros), isFavorite,
///   categoría (enum: casa, trabajo, entrenamiento, médico, otro),
///   nombre personalizado de categoría, icono (SF Symbol), fecha de creación.
@Model
public final class Place: Identifiable {
    public var id: UUID = UUID()
    public var nombre: String = ""
    public var latitud: Double = 0.0
    public var longitud: Double = 0.0
    /// Radio de la zona en metros (50 m, 75 m por defecto, o 100 m)
    public var radio: Double = 75.0
    public var isFavorite: Bool = false
    public var categoriaRaw: String = PlaceCategory.otro.rawValue
    public var nombrePersonalizadoCategoria: String? = nil
    public var icono: String = "mappin.and.ellipse"
    public var fechaCreacion: Date = Date()
    public var fechaModificacion: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \Visit.place)
    public var visitas: [Visit]? = []

    public var categoria: PlaceCategory {
        get {
            PlaceCategory(rawValue: categoriaRaw) ?? .otro
        }
        set {
            categoriaRaw = newValue.rawValue
        }
    }

    // MARK: - Propiedades de conveniencia en inglés para compatibilidad
    public var name: String {
        get { nombre }
        set { nombre = newValue }
    }
    public var latitude: Double {
        get { latitud }
        set { latitud = newValue }
    }
    public var longitude: Double {
        get { longitud }
        set { longitud = newValue }
    }
    public var radius: Double {
        get { radio }
        set { radio = newValue }
    }
    public var category: PlaceCategory {
        get { categoria }
        set { categoria = newValue }
    }
    public var customCategoryName: String? {
        get { nombrePersonalizadoCategoria }
        set { nombrePersonalizadoCategoria = newValue }
    }
    public var icon: String {
        get { icono }
        set { icono = newValue }
    }
    public var createdAt: Date {
        get { fechaCreacion }
        set { fechaCreacion = newValue }
    }
    public var updatedAt: Date {
        get { fechaModificacion }
        set { fechaModificacion = newValue }
    }
    public var coordinate: Coordinate {
        get { Coordinate(latitude: latitud, longitude: longitud) }
        set {
            latitud = newValue.latitude
            longitud = newValue.longitude
        }
    }

    public init(
        id: UUID = UUID(),
        nombre: String,
        latitud: Double,
        longitud: Double,
        radio: Double = 75.0,
        isFavorite: Bool = false,
        categoria: PlaceCategory = .otro,
        nombrePersonalizadoCategoria: String? = nil,
        icono: String? = nil,
        fechaCreacion: Date = Date(),
        fechaModificacion: Date = Date()
    ) {
        self.id = id
        self.nombre = nombre
        self.latitud = latitud
        self.longitud = longitud
        self.radio = radio
        self.isFavorite = isFavorite
        self.categoriaRaw = categoria.rawValue
        self.nombrePersonalizadoCategoria = nombrePersonalizadoCategoria
        self.icono = icono ?? categoria.defaultIcon
        self.fechaCreacion = fechaCreacion
        self.fechaModificacion = fechaModificacion
        self.visitas = []
    }

    // Inicializador con nomenclatura en inglés para conveniencia
    public convenience init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        radius: Double = 75.0,
        isFavorite: Bool = false,
        category: PlaceCategory = .otro,
        customCategoryName: String? = nil,
        icon: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.init(
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
