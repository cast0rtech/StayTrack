import Foundation

/// Reconciliador de lugares (Place) para sincronización y resolución de conflictos.
/// Aplica estrategia de última escritura gana (Last-Write-Wins basada en updatedAt)
/// sobre identificadores UUID estables.
public struct PlaceReconciler: Sendable {

    /// Combina y actualiza una lista de lugares con nuevas actualizaciones entrantes.
    public static func reconcile(
        existing: [PlaceDTO],
        incoming: [PlaceDTO]
    ) -> [PlaceDTO] {
        var map = [UUID: PlaceDTO]()
        for place in existing {
            map[place.id] = place
        }
        for place in incoming {
            if let current = map[place.id] {
                if place.updatedAt >= current.updatedAt {
                    map[place.id] = place
                }
            } else {
                map[place.id] = place
            }
        }
        return Array(map.values).sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
}
