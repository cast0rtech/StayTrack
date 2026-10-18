import Foundation
import CoreLocation

/// Asigna y asocia coordenadas y visitas a lugares conocidos (Place).
/// Implementa las reglas de dominio sobre prioridad de lugares favoritos
/// y resolución por proximidad geográfica.
public struct PlaceMatcher: Sendable {

    /// Encuentra el mejor lugar correspondiente a una coordenada dada.
    ///
    /// Regla de negocio:
    /// 1. Los lugares marcados como favoritos (`isFavorite == true`) tienen máxima prioridad
    ///    sobre lugares genéricos o sin nombre.
    /// 2. Entre lugares con la misma prioridad de favorito, los que poseen un nombre explícito
    ///    prevalecen sobre los no nombrados.
    /// 3. Si persiste el empate, se selecciona el lugar con menor distancia geodésica al punto.
    public static func findBestMatchingPlace(
        for coordinate: CLLocationCoordinate2D,
        in places: [Place]
    ) -> Place? {
        let targetLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        // Candidatos cuyo radio contiene la coordenada
        let candidatesWithDistance: [(place: Place, distance: Double)] = places.compactMap { place in
            let placeLocation = CLLocation(latitude: place.latitude, longitude: place.longitude)
            let distance = targetLocation.distance(from: placeLocation)
            guard distance <= place.radius else { return nil }
            return (place, distance)
        }

        guard !candidatesWithDistance.isEmpty else { return nil }

        // Ordenamiento jerárquico según reglas de dominio
        let sorted = candidatesWithDistance.sorted { lhs, rhs in
            // Criterio 1: Favorito
            if lhs.place.isFavorite != rhs.place.isFavorite {
                return lhs.place.isFavorite && !rhs.place.isFavorite
            }
            // Criterio 2: Nombre explícito frente a lugar sin nombre
            let lhsHasName = !lhs.place.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let rhsHasName = !rhs.place.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if lhsHasName != rhsHasName {
                return lhsHasName && !rhsHasName
            }
            // Criterio 3: Menor distancia física al centro
            return lhs.distance < rhs.distance
        }

        return sorted.first?.place
    }

    /// Versión para DTOs (útil en sincronización y procesamiento desacoplado de SwiftData)
    public static func findBestMatchingPlaceDTO(
        for coordinate: CLLocationCoordinate2D,
        in places: [PlaceDTO]
    ) -> PlaceDTO? {
        let targetLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        let candidatesWithDistance: [(place: PlaceDTO, distance: Double)] = places.compactMap { place in
            let placeLocation = CLLocation(latitude: place.latitude, longitude: place.longitude)
            let distance = targetLocation.distance(from: placeLocation)
            guard distance <= place.radius else { return nil }
            return (place, distance)
        }

        guard !candidatesWithDistance.isEmpty else { return nil }

        let sorted = candidatesWithDistance.sorted { lhs, rhs in
            if lhs.place.isFavorite != rhs.place.isFavorite {
                return lhs.place.isFavorite && !rhs.place.isFavorite
            }
            let lhsHasName = !lhs.place.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let rhsHasName = !rhs.place.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if lhsHasName != rhsHasName {
                return lhsHasName && !rhsHasName
            }
            return lhs.distance < rhs.distance
        }

        return sorted.first?.place
    }
}
