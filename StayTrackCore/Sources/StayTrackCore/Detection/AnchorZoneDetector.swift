import Foundation
import CoreLocation

/// Representa una lectura de ubicación filtrada para el motor de detección.
public struct LocationReading: Sendable {
    public let coordinate: CLLocationCoordinate2D
    public let altitude: Double
    public let horizontalAccuracy: Double
    public let timestamp: Date

    public init(
        coordinate: CLLocationCoordinate2D,
        altitude: Double = 0.0,
        horizontalAccuracy: Double,
        timestamp: Date = Date()
    ) {
        self.coordinate = coordinate
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.timestamp = timestamp
    }

    public init(from location: CLLocation) {
        self.coordinate = location.coordinate
        self.altitude = location.altitude
        self.horizontalAccuracy = location.horizontalAccuracy
        self.timestamp = location.timestamp
    }
}

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return abs(lhs.latitude - rhs.latitude) < 0.000001 &&
               abs(lhs.longitude - rhs.longitude) < 0.000001
    }
}

/// Estado interno del detector de zonas ancla
public enum DetectionState: Equatable, Sendable {
    /// Sin actividad o en desplazamiento continuo
    case idle
    /// En observación de permanencia dentro del radio (tiempo acumulado < umbral)
    case evaluatingCandidate(anchor: CLLocationCoordinate2D, firstSeen: Date, elapsed: TimeInterval)
    /// Visita confirmada activa en el punto ancla
    case activeVisit(anchor: CLLocationCoordinate2D, arrivalDate: Date)
}

/// Evento emitido por el detector
public enum DetectionEvent: Equatable, Sendable {
    /// Se confirmó una nueva visita tras superar el umbral de permanencia
    case visitStarted(anchor: CLLocationCoordinate2D, arrivalDate: Date)
    /// Se cerró la visita activa tras una salida sostenida del radio
    case visitEnded(anchor: CLLocationCoordinate2D, arrivalDate: Date, departureDate: Date)
    /// Lectura descartada por mala precisión GPS
    case readingFiltered(reason: String, accuracy: Double)
}

/// Motor de detección de check-in basado en zonas ancla y umbrales temporales.
///
/// Decisiones de arquitectura y diseño:
/// 1. Filtrado de precisión: Las lecturas GPS con horizontalAccuracy < 0 o > maxAccuracyThreshold
///    se descartan inmediatamente para evitar falsos positivos por rebotes en interiores (efecto "multipath").
/// 2. Ventana de permanencia: Requiere permanecer al menos 2 minutos dentro del radio R para
///    crear un Visit formal, evitando registrar detenciones efímeras como semáforos.
/// 3. Salida sostenida: Para evitar cerrar una estancia por una fluctuación puntual del GPS,
///    se exige una salida sostenida en el tiempo (por defecto 60 s) o un número consecutivo de lecturas externas.
public final class AnchorZoneDetector: @unchecked Sendable {
    public struct Configuration: Sendable {
        /// Radio de la zona ancla en metros (50 m, 75 m por defecto, o 100 m)
        public var detectionRadius: Double
        /// Tiempo mínimo de permanencia para confirmar check-in (por defecto: 120 s / 2 minutos)
        public var minStayDuration: TimeInterval
        /// Precisión horizontal máxima admitida en metros (por defecto: 50 m)
        public var maxAccuracyThreshold: Double
        /// Tiempo mínimo fuera de la zona para confirmar la salida sostenida (por defecto: 60 s)
        public var sustainedExitDuration: TimeInterval
        /// Consecutivas lecturas fuera de zona necesarias para confirmar salida inmediata
        public var consecutiveExitThreshold: Int

        public init(
            detectionRadius: Double = 75.0,
            minStayDuration: TimeInterval = 120.0,
            maxAccuracyThreshold: Double = 50.0,
            sustainedExitDuration: TimeInterval = 60.0,
            consecutiveExitThreshold: Int = 3
        ) {
            self.detectionRadius = detectionRadius
            self.minStayDuration = minStayDuration
            self.maxAccuracyThreshold = maxAccuracyThreshold
            self.sustainedExitDuration = sustainedExitDuration
            self.consecutiveExitThreshold = consecutiveExitThreshold
        }
    }

    public var configuration: Configuration

    // Estado del candidato a visita
    private var candidateAnchor: CLLocationCoordinate2D?
    private var candidateFirstSeen: Date?

    // Estado de la visita activa
    private var activeAnchor: CLLocationCoordinate2D?
    private var activeArrivalDate: Date?

    // Control de salida sostenida
    private var firstExitDate: Date?
    private var consecutiveExitsCount: Int = 0

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    /// Estado actual del detector
    public var currentState: DetectionState {
        if let active = activeAnchor, let arrival = activeArrivalDate {
            return .activeVisit(anchor: active, arrivalDate: arrival)
        }
        if let candidate = candidateAnchor, let first = candidateFirstSeen {
            return .evaluatingCandidate(
                anchor: candidate,
                firstSeen: first,
                elapsed: Date().timeIntervalSince(first)
            )
        }
        return .idle
    }

    /// Procesa una lectura de ubicación entrante.
    /// Retorna un evento si se produjo un inicio, fin o filtrado de visita.
    @discardableResult
    public func process(reading: LocationReading) -> DetectionEvent? {
        // Regla 1: Filtrado de precisión GPS
        guard reading.horizontalAccuracy >= 0 else {
            return .readingFiltered(reason: "Precisión inválida negativa", accuracy: reading.horizontalAccuracy)
        }
        guard reading.horizontalAccuracy <= configuration.maxAccuracyThreshold else {
            return .readingFiltered(reason: "Precisión insuficiente (> \(configuration.maxAccuracyThreshold)m)", accuracy: reading.horizontalAccuracy)
        }

        let currentLocation = CLLocation(latitude: reading.coordinate.latitude, longitude: reading.coordinate.longitude)

        // Caso A: Ya hay una visita activa confirmada
        if let anchor = activeAnchor, let arrival = activeArrivalDate {
            let anchorLocation = CLLocation(latitude: anchor.latitude, longitude: anchor.longitude)
            let distance = currentLocation.distance(from: anchorLocation)

            if distance <= configuration.detectionRadius {
                // El usuario sigue dentro de la zona ancla: reseteamos contadores de salida
                firstExitDate = nil
                consecutiveExitsCount = 0
                return nil
            } else {
                // El usuario está fuera del radio de la zona ancla
                if firstExitDate == nil {
                    firstExitDate = reading.timestamp
                }
                consecutiveExitsCount += 1

                let timeOutside = reading.timestamp.timeIntervalSince(firstExitDate ?? reading.timestamp)

                // Cierre de visita por salida sostenida (tiempo o lecturas consecutivas)
                if timeOutside >= configuration.sustainedExitDuration ||
                    consecutiveExitsCount >= configuration.consecutiveExitThreshold {
                    let departure = firstExitDate ?? reading.timestamp
                    let closedAnchor = anchor
                    let closedArrival = arrival

                    // Resetear estado
                    activeAnchor = nil
                    activeArrivalDate = nil
                    firstExitDate = nil
                    consecutiveExitsCount = 0
                    candidateAnchor = nil
                    candidateFirstSeen = nil

                    return .visitEnded(anchor: closedAnchor, arrivalDate: closedArrival, departureDate: departure)
                }
                return nil
            }
        }

        // Caso B: Evaluando candidato a visita
        if let candidate = candidateAnchor, let firstSeen = candidateFirstSeen {
            let candidateLocation = CLLocation(latitude: candidate.latitude, longitude: candidate.longitude)
            let distance = currentLocation.distance(from: candidateLocation)

            if distance <= configuration.detectionRadius {
                let stayDuration = reading.timestamp.timeIntervalSince(firstSeen)
                if stayDuration >= configuration.minStayDuration {
                    // Check-in confirmado: ha permanecido más de 2 minutos dentro de la zona
                    activeAnchor = candidate
                    activeArrivalDate = firstSeen
                    candidateAnchor = nil
                    candidateFirstSeen = nil
                    firstExitDate = nil
                    consecutiveExitsCount = 0

                    return .visitStarted(anchor: candidate, arrivalDate: firstSeen)
                }
                return nil
            } else {
                // Salió del radio antes de cumplir los 2 minutos: reiniciamos el candidato
                candidateAnchor = reading.coordinate
                candidateFirstSeen = reading.timestamp
                return nil
            }
        }

        // Caso C: Sin candidato previo, inicializar nuevo candidato ancla
        candidateAnchor = reading.coordinate
        candidateFirstSeen = reading.timestamp
        return nil
    }

    /// Fuerza el cierre de una visita activa (ej. apagado de app o fin de sesión)
    public func forceCloseActiveVisit(at departureDate: Date = Date()) -> DetectionEvent? {
        guard let anchor = activeAnchor, let arrival = activeArrivalDate else {
            return nil
        }
        activeAnchor = nil
        activeArrivalDate = nil
        firstExitDate = nil
        consecutiveExitsCount = 0
        candidateAnchor = nil
        candidateFirstSeen = nil
        return .visitEnded(anchor: anchor, arrivalDate: arrival, departureDate: departureDate)
    }

    /// Resetea por completo el detector
    public func reset() {
        activeAnchor = nil
        activeArrivalDate = nil
        firstExitDate = nil
        consecutiveExitsCount = 0
        candidateAnchor = nil
        candidateFirstSeen = nil
    }
}
