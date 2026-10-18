import Foundation

/// Muestra de ubicación pura e independiente de CoreLocation.
public struct LocationSample: Sendable, Equatable {
    public let coordinate: Coordinate
    public let horizontalAccuracy: Double
    public let timestamp: Date

    public init(
        coordinate: Coordinate,
        horizontalAccuracy: Double,
        timestamp: Date = Date()
    ) {
        self.coordinate = coordinate
        self.horizontalAccuracy = horizontalAccuracy
        self.timestamp = timestamp
    }

    public init(
        latitude: Double,
        longitude: Double,
        accuracy: Double,
        timestamp: Date = Date()
    ) {
        self.coordinate = Coordinate(latitude: latitude, longitude: longitude)
        self.horizontalAccuracy = accuracy
        self.timestamp = timestamp
    }
}

/// Estado interno del detector de zonas ancla
public enum DetectionState: Equatable, Sendable {
    /// Sin actividad o en desplazamiento continuo
    case idle
    /// En observación de permanencia dentro del radio (tiempo acumulado < umbral de 2 minutos)
    case evaluatingCandidate(anchor: Coordinate, firstSeen: Date)
    /// Visita confirmada activa en el punto ancla
    case activeVisit(anchor: Coordinate, arrivalDate: Date)
}

/// Evento emitido por el detector de estancia
public enum DetectionEvent: Equatable, Sendable {
    /// Se confirmó una nueva visita tras permanecer más de 2 minutos dentro del radio
    case visitStarted(anchor: Coordinate, arrivalDate: Date, accuracy: Double)
    /// Se cerró la visita activa tras una salida sostenida del radio
    case visitEnded(anchor: Coordinate, arrivalDate: Date, departureDate: Date, accuracy: Double)
    /// Lectura descartada por mala precisión GPS (independiente de CoreLocation)
    case readingFiltered(reason: String, accuracy: Double)
}

/// Motor de detección de estancia por zona ancla.
///
/// Lógica pura y testeable, independiente de CoreLocation:
/// 1. Empieza cuando el usuario permanece más de 2 minutos dentro de un radio R
///    (50 m o 100 m, configurable, por defecto 75 m) desde un punto ancla.
/// 2. Termina al salir de la zona de forma sostenida (por tiempo o lecturas consecutivas).
/// 3. Ignora lecturas con mala precisión (precisión negativa o > maxAccuracyThreshold).
/// 4. Protegido contra salidas falsas por deriva GPS puntual.
public final class AnchorZoneDetector: @unchecked Sendable {
    public struct Configuration: Sendable, Equatable {
        /// Radio de la zona ancla en metros (50 m, 75 m por defecto, o 100 m)
        public var detectionRadius: Double
        /// Tiempo mínimo de permanencia para confirmar check-in (por defecto: 120 s / 2 minutos)
        public var minStayDuration: TimeInterval
        /// Precisión horizontal máxima admitida en metros (por defecto: 50 m)
        public var maxAccuracyThreshold: Double
        /// Tiempo mínimo fuera de la zona para confirmar salida sostenida (por defecto: 60 s)
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
    private var candidateAnchor: Coordinate?
    private var candidateFirstSeen: Date?

    // Estado de la visita activa
    private var activeAnchor: Coordinate?
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
            return .evaluatingCandidate(anchor: candidate, firstSeen: first)
        }
        return .idle
    }

    /// Procesa una muestra de ubicación pura.
    /// Retorna un evento si se produjo un inicio, fin o filtrado de visita.
    @discardableResult
    public func process(sample: LocationSample) -> DetectionEvent? {
        // Regla 1: Ignora lecturas con mala precisión
        guard sample.horizontalAccuracy >= 0 else {
            return .readingFiltered(reason: "Precisión negativa inválida", accuracy: sample.horizontalAccuracy)
        }
        guard sample.horizontalAccuracy <= configuration.maxAccuracyThreshold else {
            return .readingFiltered(
                reason: "Precisión insuficiente (> \(configuration.maxAccuracyThreshold)m)",
                accuracy: sample.horizontalAccuracy
            )
        }

        // Caso A: Ya hay una visita activa confirmada
        if let anchor = activeAnchor, let arrival = activeArrivalDate {
            let distance = sample.coordinate.distance(to: anchor)

            if distance <= configuration.detectionRadius {
                // El usuario sigue dentro del radio de la zona ancla
                // Se restablece cualquier salida transitoria (evita cierre por deriva GPS puntual)
                firstExitDate = nil
                consecutiveExitsCount = 0
                return nil
            } else {
                // El usuario está fuera del radio de la zona ancla
                if firstExitDate == nil {
                    firstExitDate = sample.timestamp
                }
                consecutiveExitsCount += 1

                let timeOutside = sample.timestamp.timeIntervalSince(firstExitDate ?? sample.timestamp)

                // Salida sostenida confirmada por tiempo acumulado o lecturas consecutivas
                if timeOutside >= configuration.sustainedExitDuration ||
                    consecutiveExitsCount >= configuration.consecutiveExitThreshold {
                    let departure = firstExitDate ?? sample.timestamp
                    let closedAnchor = anchor
                    let closedArrival = arrival

                    // Resetear estado
                    activeAnchor = nil
                    activeArrivalDate = nil
                    firstExitDate = nil
                    consecutiveExitsCount = 0
                    candidateAnchor = nil
                    candidateFirstSeen = nil

                    return .visitEnded(
                        anchor: closedAnchor,
                        arrivalDate: closedArrival,
                        departureDate: departure,
                        accuracy: sample.horizontalAccuracy
                    )
                }
                return nil
            }
        }

        // Caso B: Evaluando candidato a visita
        if let candidate = candidateAnchor, let firstSeen = candidateFirstSeen {
            let distance = sample.coordinate.distance(to: candidate)

            if distance <= configuration.detectionRadius {
                let stayDuration = sample.timestamp.timeIntervalSince(firstSeen)
                if stayDuration >= configuration.minStayDuration {
                    // Check-in confirmado: permanece más de 2 minutos dentro del radio
                    activeAnchor = candidate
                    activeArrivalDate = firstSeen
                    candidateAnchor = nil
                    candidateFirstSeen = nil
                    firstExitDate = nil
                    consecutiveExitsCount = 0

                    return .visitStarted(
                        anchor: candidate,
                        arrivalDate: firstSeen,
                        accuracy: sample.horizontalAccuracy
                    )
                }
                return nil
            } else {
                // Salió del radio antes de cumplir los 2 minutos: reinicia candidato
                candidateAnchor = sample.coordinate
                candidateFirstSeen = sample.timestamp
                return nil
            }
        }

        // Caso C: Sin candidato previo, inicializar nuevo candidato ancla
        candidateAnchor = sample.coordinate
        candidateFirstSeen = sample.timestamp
        return nil
    }

    /// Fuerza el cierre de una visita activa
    public func forceCloseActiveVisit(at departureDate: Date = Date(), accuracy: Double = 10.0) -> DetectionEvent? {
        guard let anchor = activeAnchor, let arrival = activeArrivalDate else {
            return nil
        }
        activeAnchor = nil
        activeArrivalDate = nil
        firstExitDate = nil
        consecutiveExitsCount = 0
        candidateAnchor = nil
        candidateFirstSeen = nil
        return .visitEnded(anchor: anchor, arrivalDate: arrival, departureDate: departureDate, accuracy: accuracy)
    }

    /// Resetea por completo el estado del detector
    public func reset() {
        activeAnchor = nil
        activeArrivalDate = nil
        firstExitDate = nil
        consecutiveExitsCount = 0
        candidateAnchor = nil
        candidateFirstSeen = nil
    }
}
