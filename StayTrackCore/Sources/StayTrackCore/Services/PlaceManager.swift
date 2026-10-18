import Foundation

/// Gestor de lugares y favoritos.
///
/// Implementa los requisitos de dominio:
/// - Crear, editar, renombrar y fusionar lugares.
/// - Crear un favorito desde una estancia existente o desde una ubicación.
/// - Al renombrar o fusionar, actualiza el histórico de visitas.
public struct PlaceManager: Sendable {

    // MARK: - Creación y Edición

    /// Crea un nuevo lugar
    @discardableResult
    public static func createPlace(
        nombre: String,
        coordenada: Coordinate,
        radio: Double = 75.0,
        isFavorite: Bool = false,
        categoria: PlaceCategory = .otro,
        nombrePersonalizadoCategoria: String? = nil,
        icono: String? = nil,
        places: inout [Place]
    ) -> Place {
        let place = Place(
            nombre: nombre,
            latitud: coordenada.latitude,
            longitud: coordenada.longitude,
            radio: radio,
            isFavorite: isFavorite,
            categoria: categoria,
            nombrePersonalizadoCategoria: nombrePersonalizadoCategoria,
            icono: icono ?? categoria.defaultIcon
        )
        places.append(place)
        return place
    }

    /// Edita un lugar existente
    public static func editPlace(
        place: Place,
        nombre: String,
        radio: Double,
        isFavorite: Bool,
        categoria: PlaceCategory,
        nombrePersonalizadoCategoria: String? = nil,
        icono: String? = nil
    ) {
        place.nombre = nombre
        place.radio = radio
        place.isFavorite = isFavorite
        place.categoria = categoria
        place.nombrePersonalizadoCategoria = nombrePersonalizadoCategoria
        if let ico = icono {
            place.icono = ico
        }
        place.fechaModificacion = Date()
    }

    /// Renombra un lugar y actualiza el histórico asociado
    public static func renamePlace(
        place: Place,
        nuevoNombre: String,
        visitas: [Visit]
    ) {
        place.nombre = nuevoNombre
        place.fechaModificacion = Date()

        // Actualizar histórico: marcar fecha de modificación de las visitas afectadas
        for visit in visitas where visit.placeId == place.id {
            visit.place = place
            visit.fechaModificacion = Date()
        }
    }

    /// Fusiona un lugar origen ('source') dentro de un lugar destino ('target').
    /// Reasigna todas las visitas históricas del origen al destino y elimina el origen.
    public static func mergePlaces(
        source: Place,
        into target: Place,
        places: inout [Place],
        visitas: inout [Visit]
    ) {
        guard source.id != target.id else { return }

        // Si el origen era favorito, el destino hereda el estado de favorito
        if source.isFavorite {
            target.isFavorite = true
        }

        // Actualizar el histórico de visitas: todas las visitas del origen apuntan ahora al destino
        for visit in visitas where visit.placeId == source.id {
            visit.placeId = target.id
            visit.place = target
            visit.fechaModificacion = Date()
        }

        // Eliminar el lugar origen
        places.removeAll { $0.id == source.id }
        target.fechaModificacion = Date()
    }

    /// Crea un lugar favorito a partir de una estancia existente
    @discardableResult
    public static func createFavoriteFromVisit(
        visit: Visit,
        nombre: String,
        categoria: PlaceCategory = .casa,
        radio: Double = 75.0,
        icono: String? = nil,
        places: inout [Place]
    ) -> Place {
        let place = Place(
            nombre: nombre,
            latitud: visit.latitudAncla,
            longitud: visit.longitudAncla,
            radio: radio,
            isFavorite: true,
            categoria: categoria,
            nombrePersonalizadoCategoria: nil,
            icono: icono ?? categoria.defaultIcon
        )
        places.append(place)

        // Asignar inmediatamente la visita al nuevo favorito
        visit.placeId = place.id
        visit.place = place
        visit.fechaModificacion = Date()

        return place
    }

    /// Crea un lugar favorito a partir de una coordenada/ubicación
    @discardableResult
    public static func createFavoriteFromLocation(
        coordenada: Coordinate,
        nombre: String,
        categoria: PlaceCategory = .casa,
        radio: Double = 75.0,
        icono: String? = nil,
        places: inout [Place]
    ) -> Place {
        let place = Place(
            nombre: nombre,
            latitud: coordenada.latitude,
            longitud: coordenada.longitude,
            radio: radio,
            isFavorite: true,
            categoria: categoria,
            nombrePersonalizadoCategoria: nil,
            icono: icono ?? categoria.defaultIcon
        )
        places.append(place)
        return place
    }

    // MARK: - Versiones DTO (Lógica Pura sin persistencia)

    public static func renamePlaceDTO(
        placeId: UUID,
        nuevoNombre: String,
        places: inout [PlaceDTO],
        visitas: inout [VisitDTO]
    ) {
        if let idx = places.firstIndex(where: { $0.id == placeId }) {
            places[idx].name = nuevoNombre
            places[idx].updatedAt = Date()
        }
        for i in 0..<visitas.count where visitas[i].placeId == placeId {
            visitas[i].updatedAt = Date()
        }
    }

    public static func mergePlacesDTO(
        sourceId: UUID,
        into targetId: UUID,
        places: inout [PlaceDTO],
        visitas: inout [VisitDTO]
    ) {
        guard sourceId != targetId else { return }

        let sourcePlace = places.first { $0.id == sourceId }

        if let idx = places.firstIndex(where: { $0.id == targetId }) {
            if sourcePlace?.isFavorite == true {
                places[idx].isFavorite = true
            }
            places[idx].updatedAt = Date()
        }

        for i in 0..<visitas.count where visitas[i].placeId == sourceId {
            visitas[i].placeId = targetId
            visitas[i].updatedAt = Date()
        }

        places.removeAll { $0.id == sourceId }
    }

    @discardableResult
    public static func createFavoriteFromVisitDTO(
        visit: inout VisitDTO,
        nombre: String,
        categoria: PlaceCategory = .casa,
        radio: Double = 75.0,
        places: inout [PlaceDTO]
    ) -> PlaceDTO {
        let place = PlaceDTO(
            id: UUID(),
            name: nombre,
            isFavorite: true,
            category: categoria,
            customCategoryName: nil,
            icon: categoria.defaultIcon,
            latitude: visit.latitude,
            longitude: visit.longitude,
            radius: radio
        )
        places.append(place)
        visit.placeId = place.id
        visit.updatedAt = Date()
        return place
    }

    @discardableResult
    public static func createFavoriteFromLocationDTO(
        coordenada: Coordinate,
        nombre: String,
        categoria: PlaceCategory = .casa,
        radio: Double = 75.0,
        places: inout [PlaceDTO]
    ) -> PlaceDTO {
        let place = PlaceDTO(
            id: UUID(),
            name: nombre,
            isFavorite: true,
            category: categoria,
            customCategoryName: nil,
            icon: categoria.defaultIcon,
            latitude: coordenada.latitude,
            longitude: coordenada.longitude,
            radius: radio
        )
        places.append(place)
        return place
    }
}
