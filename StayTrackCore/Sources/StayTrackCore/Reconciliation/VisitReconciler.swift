import Foundation

/// Motor de reconciliación de estancias entre Apple Watch e iPhone.
///
/// Reglas de dominio implementadas:
/// 1. Prioridad del Apple Watch: El reloj tiene prioridad.
/// 2. Solapamiento con reloj: Un Visit de origen phone que se solape con movimiento del reloj
///    (MovementSample o Visit watch en otro lugar) se recorta o descarta en el tramo solapado.
/// 3. Casos de solapamiento:
///    - Solapamiento total: El Visit del phone queda totalmente cubierto -> se descarta.
///    - Solapamiento parcial: Se recorta en el inicio (cabeza) o fin (cola) según la frontera del reloj.
///      Si tras el recorte la duración resultante es inferior a 2 minutos (120 s), se descarta.
///    - Solapamiento nulo: No existe intersección temporal; la estancia del phone se conserva íntegra.
public struct VisitReconciler: Sendable {
    /// Duración mínima en segundos para que una estancia recortada siga siendo válida
    public static let minimumValidDuration: TimeInterval = 120.0

    /// Reconcilia visitas de iPhone considerando tanto visitas del Watch como muestras de movimiento del reloj.
    public static func reconcile(
        iphoneVisits: [VisitDTO],
        watchVisits: [VisitDTO] = [],
        watchMovements: [MovementSampleDTO] = []
    ) -> [VisitDTO] {
        // Construir lista de intervalos dominantes del reloj (visitas del watch + muestras de movimiento del watch)
        var watchIntervals: [DateInterval] = []

        for wv in watchVisits {
            let start = wv.startDate
            let end = wv.endDate ?? Date()
            if end > start {
                watchIntervals.append(DateInterval(start: start, end: end))
            }
        }

        for wm in watchMovements where wm.device == .watch {
            let start = wm.startDate
            let end = wm.endDate
            if end > start {
                watchIntervals.append(DateInterval(start: start, end: end))
            }
        }

        var reconciledPhoneVisits: [VisitDTO] = []

        for phoneVisit in iphoneVisits {
            var segments: [VisitDTO] = [phoneVisit]

            // Recortar secuencialmente contra cada intervalo de actividad del reloj
            for interval in watchIntervals {
                var nextSegments: [VisitDTO] = []

                for segment in segments {
                    let adjusted = trimSegment(segment, against: interval)
                    nextSegments.append(contentsOf: adjusted)
                }

                segments = nextSegments
                if segments.isEmpty { break }
            }

            reconciledPhoneVisits.append(contentsOf: segments)
        }

        // Combinar visitas del watch (intactas) y las visitas del phone reconciliadas
        var allVisits = watchVisits
        allVisits.append(contentsOf: reconciledPhoneVisits)

        // Ordenar cronológicamente por fecha de inicio
        return allVisits.sorted { $0.startDate < $1.startDate }
    }

    /// Resuelve el conflicto entre un segmento de visita de iPhone y un intervalo del Watch
    public static func trimSegment(
        _ segment: VisitDTO,
        against watchInterval: DateInterval
    ) -> [VisitDTO] {
        let pStart = segment.startDate
        let pEnd = segment.endDate ?? Date()

        let wStart = watchInterval.start
        let wEnd = watchInterval.end

        // 1. Solapamiento nulo: no hay intersección temporal
        let overlapStart = max(pStart, wStart)
        let overlapEnd = min(pEnd, wEnd)
        guard overlapStart < overlapEnd else {
            return [segment]
        }

        // 2. Solapamiento total: El Watch cubre completamente la estancia del iPhone
        if wStart <= pStart && wEnd >= pEnd {
            return [] // Descartar totalmente
        }

        // 3. Solapamiento total inverso: El Watch ocurre en medio de la estancia del iPhone
        if pStart < wStart && pEnd > wEnd {
            var result: [VisitDTO] = []

            // Tramo anterior al Watch
            let preDuration = wStart.timeIntervalSince(pStart)
            if preDuration >= minimumValidDuration {
                var pre = segment
                pre.id = UUID()
                pre.endDate = wStart
                pre.updatedAt = Date()
                result.append(pre)
            }

            // Tramo posterior al Watch
            let postDuration = pEnd.timeIntervalSince(wEnd)
            if postDuration >= minimumValidDuration {
                var post = segment
                post.id = UUID()
                post.startDate = wEnd
                post.updatedAt = Date()
                result.append(post)
            }

            return result
        }

        // 4. Solapamiento parcial (cola): El iPhone empezó antes, y el Watch solapó el final
        if pStart < wStart && pEnd <= wEnd {
            let remainingDuration = wStart.timeIntervalSince(pStart)
            if remainingDuration >= minimumValidDuration {
                var trimmed = segment
                trimmed.endDate = wStart
                trimmed.updatedAt = Date()
                return [trimmed]
            } else {
                return []
            }
        }

        // 5. Solapamiento parcial (cabeza): El Watch solapó el inicio del iPhone
        if pStart >= wStart && pEnd > wEnd {
            let remainingDuration = pEnd.timeIntervalSince(wEnd)
            if remainingDuration >= minimumValidDuration {
                var trimmed = segment
                trimmed.startDate = wEnd
                trimmed.updatedAt = Date()
                return [trimmed]
            } else {
                return []
            }
        }

        return [segment]
    }
}
