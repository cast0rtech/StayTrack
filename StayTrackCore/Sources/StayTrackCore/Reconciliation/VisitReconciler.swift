import Foundation

/// Motor de reconciliación de estancias entre Apple Watch e iPhone.
///
/// Reglas de dominio implementadas:
/// 1. Prioridad del Apple Watch: Cuando el Watch registra datos en el mismo intervalo temporal,
///    sus estancias prevalecen sobre las del iPhone.
/// 2. Dispositivo en movimiento vs. Estático: Si el iPhone quedó quieto (ej. olvidado en una mesa)
///    mientras el Watch detectó movimiento o registró estancia en otro lugar, el dispositivo que se mueve
///    prevalece, recortando o descartando la estancia del iPhone en el tramo solapado.
/// 3. Tipos de solapamiento:
///    - Solapamiento total: El iPhone queda totalmente absorbido por el Watch -> la estancia del iPhone se descarta.
///    - Solapamiento parcial (inicio o fin): La estancia del iPhone se recorta en la frontera de la estancia del Watch.
///      Si tras el recorte la duración resultante es inferior a 2 minutos (120 s), se descarta.
///    - Solapamiento nulo: Ambas estancias coexisten sin alteración.
/// 4. Upsert por UUID estable: Garantiza idempotencia ante sincronizaciones repetidas.
public struct VisitReconciler: Sendable {
    /// Duración mínima en segundos para que una estancia recortada siga siendo válida
    public static let minimumValidDuration: TimeInterval = 120.0

    /// Reconcilia listas de VisitDTO provenientes de iPhone y Apple Watch.
    public static func reconcile(
        iphoneVisits: [VisitDTO],
        watchVisits: [VisitDTO]
    ) -> [VisitDTO] {
        // Mapa base con las visitas del Watch (las cuales tienen prioridad y no se recortan por el iPhone)
        var reconciledWatchVisits = [UUID: VisitDTO]()
        for visit in watchVisits {
            reconciledWatchVisits[visit.id] = visit
        }

        var adjustedIphoneVisits = [VisitDTO]()

        for iphoneVisit in iphoneVisits {
            var segments: [VisitDTO] = [iphoneVisit]

            // Iterar sobre cada visita del Watch para aplicar recortes / descartes en caso de conflicto
            for (_, watchVisit) in reconciledWatchVisits {
                var nextSegments = [VisitDTO]()

                for segment in segments {
                    let result = reconcileSegment(iphoneSegment: segment, against: watchVisit)
                    nextSegments.append(contentsOf: result)
                }

                segments = nextSegments
                if segments.isEmpty {
                    break
                }
            }

            adjustedIphoneVisits.append(contentsOf: segments)
        }

        // Combinar todas las visitas reconciliadas
        var allVisits = Array(reconciledWatchVisits.values)
        allVisits.append(contentsOf: adjustedIphoneVisits)

        // Ordenar cronológicamente por llegada
        return allVisits.sorted { $0.arrivalDate < $1.arrivalDate }
    }

    /// Resuelve el conflicto entre un segmento de visita de iPhone y una visita de Apple Watch.
    /// Retorna 0, 1 o 2 segmentos de iPhone ajustados.
    public static func reconcileSegment(
        iphoneSegment: VisitDTO,
        against watchVisit: VisitDTO
    ) -> [VisitDTO] {
        let ipArrival = iphoneSegment.arrivalDate
        let ipDeparture = iphoneSegment.departureDate ?? Date()

        let wArrival = watchVisit.arrivalDate
        let wDeparture = watchVisit.departureDate ?? Date()

        // 1. Comprobar si existe solapamiento temporal
        let overlapStart = max(ipArrival, wArrival)
        let overlapEnd = min(ipDeparture, wDeparture)

        // Solapamiento nulo: no hay intersección temporal
        guard overlapStart < overlapEnd else {
            return [iphoneSegment]
        }

        // 2. Solapamiento Total:
        // Caso A: El Watch cubre completamente el intervalo del iPhone
        if wArrival <= ipArrival && wDeparture >= ipDeparture {
            // El Visit del iPhone queda totalmente descartado
            return []
        }

        // 3. Solapamiento Total Inverso: El iPhone cubre completamente al Watch (el Watch está en medio)
        if ipArrival < wArrival && ipDeparture > wDeparture {
            var result = [VisitDTO]()

            // Segmento previo al Watch
            let preDuration = wArrival.timeIntervalSince(ipArrival)
            if preDuration >= minimumValidDuration {
                var pre = iphoneSegment
                pre.id = UUID() // Nuevo segmento con UUID único derivado
                pre.departureDate = wArrival
                pre.updatedAt = Date()
                result.append(pre)
            }

            // Segmento posterior al Watch
            let postDuration = ipDeparture.timeIntervalSince(wDeparture)
            if postDuration >= minimumValidDuration {
                var post = iphoneSegment
                post.id = UUID()
                post.arrivalDate = wDeparture
                post.updatedAt = Date()
                result.append(post)
            }

            return result
        }

        // 4. Solapamiento Parcial (Cola): El iPhone empezó antes, pero el Watch empezó antes de que el iPhone terminara
        if ipArrival < wArrival && ipDeparture <= wDeparture {
            let remainingDuration = wArrival.timeIntervalSince(ipArrival)
            if remainingDuration >= minimumValidDuration {
                var trimmed = iphoneSegment
                trimmed.departureDate = wArrival
                trimmed.updatedAt = Date()
                return [trimmed]
            } else {
                return []
            }
        }

        // 5. Solapamiento Parcial (Cabeza): El Watch empezó antes, y el iPhone continuó después de la salida del Watch
        if ipArrival >= wArrival && ipDeparture > wDeparture {
            let remainingDuration = ipDeparture.timeIntervalSince(wDeparture)
            if remainingDuration >= minimumValidDuration {
                var trimmed = iphoneSegment
                trimmed.arrivalDate = wDeparture
                trimmed.updatedAt = Date()
                return [trimmed]
            } else {
                return []
            }
        }

        return [iphoneSegment]
    }

    /// Realiza upsert de visitas en un diccionario existente basado en UUID y updatedAt.
    public static func upsertVisits(
        incoming: [VisitDTO],
        into existing: inout [UUID: VisitDTO]
    ) {
        for visit in incoming {
            if let current = existing[visit.id] {
                if visit.updatedAt >= current.updatedAt {
                    existing[visit.id] = visit
                }
            } else {
                existing[visit.id] = visit
            }
        }
    }
}
