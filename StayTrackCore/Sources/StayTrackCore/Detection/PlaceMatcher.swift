import Foundation

/// Motor de asignación de estancias a lugares (Place).
///
/// Reglas de dominio implementadas:
/// 1. Al cerrar una estancia, asígnala al Place más cercano cuyo radio la contenga.
/// 2. Prioridad estricta para favoritos (isFavorite == true) sobre lugares no favoritos.
/// 3. Si no encaja en ningún lugar existente, crea un Place sin nombre con las coordenadas
///    del punto ancla y el radio por defecto.
public struct PlaceMatcher: Sendable {

    /// Busca el lugar más idóneo cuyo radio contenga la coordenada, priorizando favoritos.
    public static func findBestMatchingPlace(
        for coordinate: Coordinate,
        in places: [Place]
    ) -> Place? {
        // Filtrar aquellos lugares cuyo radio contiene el punto
        let candidatesWithDistance: [(place: Place, distance: Double)] = places.compactMap { place in
            let distance = coordinate.distance(to: place.coordinate)
            guard distance <= place.radio else { return nil }
            return (place, distance)
        }

        guard !candidatesWithDistance.isEmpty else { return nil }

        // Ordenamiento jerárquico según reglas de dominio
        let sorted = candidatesWithDistance.sorted { lhs, rhs in
            // Criterio 1: Prioridad para favoritos
            if lhs.place.isFavorite != rhs.place.isFavorite {
                return lhs.place.isFavorite && !rhs.place.isFavorite
            }
            // Criterio 2: El más cercano
            return lhs.distance < rhs.distance
        }

        return sorted.first?.place
    }

    /// Asigna un lugar a la visita. Si ningún lugar la contiene, crea y retorna un Place sin nombre.
    @discardableResult
    public static func assignPlace(
        to visit: Visit,
        in places: inout [Place],
        defaultRadius: Double = 75.0
    ) -> Place {
        if let matched = findBestMatchingPlace(for: visit.coordenadaAncla, in: places) {
            visit.placeId = matched.id
            visit.place = matched
            return matched
        } else {
            // Si no encaja, crea un Place sin nombre
            let newPlace = Place(
                nombre: "",
                latitud: visit.latitudAncla,
                longitud: visit.longitudAncla,
                radio: defaultRadius,
                isFavorite: false,
                categoria: .otro,
                nombrePersonalizadoCategoria: nil,
                icono: PlaceCategory.otro.defaultIcon
            )
            places.append(newPlace)
            visit.placeId = newPlace.id
            visit.place = newPlace
            return newPlace
        }
    }

    /// Asignación para DTOs (útil para lógica pura y tests sin persistencia)
    public static func findBestMatchingPlaceDTO(
        for coordinate: Coordinate,
        in places: [PlaceDTO]
    ) -> PlaceDTO? {
        let candidatesWithDistance: [(place: PlaceDTO, distance: Double)] = places.compactMap { place in
            let distance = coordinate.distance(to: place.coordinate)
            guard distance <= place.radius else { return nil }
            return (place, distance)
        }

        guard !candidatesWithDistance.isEmpty else { return nil }

        let sorted = candidatesWithDistance.sorted { lhs, rhs in
            if lhs.place.isFavorite != rhs.place.isFavorite {
                return lhs.place.isFavorite && !rhs.place.isFavorite
            }
            return lhs.distance < rhs.distance
        }

        return sorted.first?.place
    }

    /// Asigna o crea PlaceDTO para estancias DTO
    @discardableResult
    public static func assignPlaceDTO(
        to visit: inout VisitDTO,
        in places: inout [PlaceDTO],
        defaultRadius: Double = 75.0
    ) -> PlaceDTO {
        if let matched = findBestMatchingPlaceDTO(for: visit.anchorCoordinate, in: places) {
            visit.placeId = matched.id
            return matched
        } else {
            let newPlace = PlaceDTO(
                id: UUID(),
                name: "",
                isFavorite: false,
                category: .otro,
                customCategoryName: nil,
                icon: PlaceCategory.otro.defaultIcon,
                latitude: visit.latitude,
                longitude: visit.longitude,
                radius: defaultRadius
            )
            places.append(newPlace)
            visit.placeId = newPlace.id
            return newPlace
        }
    }
}
