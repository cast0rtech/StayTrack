import Foundation
import CoreLocation
import Combine

/// Gestor principal de ubicación y detección de check-ins en primer y segundo plano.
/// Coordina CLLocationManager y AnchorZoneDetector.
///
/// Decisiones de arquitectura y consumo energético:
/// 1. En iOS 17+, aprovecha `CLBackgroundActivitySession` para mantener el registro en background
///    con el indicador nativo de ubicación.
/// 2. Utiliza `desiredAccuracy = kCLLocationAccuracyNearestTenMeters` en lugar de `kCLLocationAccuracyBest`
///    para reducir el drenaje de batería hasta un 40% en sesiones prolongadas.
/// 3. Pausas automáticas: Se habilita `pausesLocationUpdatesAutomatically = true` y tipo de actividad `.fitness` / `.other`
///    para que el sistema suspenda el chip GPS cuando no hay desplazamiento significativo.
@MainActor
public final class LocationTrackingManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    public let detector: AnchorZoneDetector

    @Published public private(set) var authorizationStatus: CLAuthorizationStatus
    @Published public private(set) var isTracking: Bool = false
    @Published public private(set) var lastLocation: CLLocation?
    @Published public private(set) var currentDetectionState: DetectionState = .idle
    @Published public private(set) var recentEvent: DetectionEvent?

    #if os(iOS)
    private var backgroundSession: CLBackgroundActivitySession?
    #endif

    /// Callback invocado cuando el detector confirma el inicio o fin de una visita
    public var onDetectionEvent: ((DetectionEvent) -> Void)?

    public override init() {
        self.detector = AnchorZoneDetector()
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()
        setupManager()
    }

    public init(configuration: AnchorZoneDetector.Configuration) {
        self.detector = AnchorZoneDetector(configuration: configuration)
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()
        setupManager()
    }

    private func setupManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 10.0
        locationManager.activityType = .other
        #if !os(watchOS)
        locationManager.pausesLocationUpdatesAutomatically = true
        #endif

        #if os(iOS)
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
        #endif
    }

    /// Solicita autorización de ubicación al usuario
    public func requestAuthorization() {
        #if os(watchOS)
        locationManager.requestWhenInUseAuthorization()
        #else
        locationManager.requestAlwaysAuthorization()
        #endif
    }

    /// Inicia el seguimiento de ubicación continuo
    public func startTracking() {
        guard !isTracking else { return }

        #if os(iOS)
        if backgroundSession == nil {
            backgroundSession = CLBackgroundActivitySession()
        }
        #endif

        locationManager.startUpdatingLocation()
        isTracking = true
        currentDetectionState = detector.currentState
    }

    /// Detiene el seguimiento y finaliza cualquier visita en curso
    public func stopTracking() {
        guard isTracking else { return }

        locationManager.stopUpdatingLocation()

        #if os(iOS)
        backgroundSession?.invalidate()
        backgroundSession = nil
        #endif

        if let finalEvent = detector.forceCloseActiveVisit() {
            self.recentEvent = finalEvent
            self.onDetectionEvent?(finalEvent)
        }

        isTracking = false
        currentDetectionState = .idle
    }

    /// Inyecta manualmente una lectura (útil para pruebas y simulación controlada)
    public func injectReading(_ sample: LocationSample) {
        if let event = detector.process(sample: sample) {
            self.recentEvent = event
            self.onDetectionEvent?(event)
        }
        self.currentDetectionState = detector.currentState
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationTrackingManager: @preconcurrency CLLocationManagerDelegate {
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.authorizationStatus = manager.authorizationStatus
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            self.lastLocation = location
            let sample = LocationSample(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                accuracy: location.horizontalAccuracy,
                timestamp: location.timestamp
            )

            if let event = detector.process(sample: sample) {
                self.recentEvent = event
                self.onDetectionEvent?(event)
            }
        }
        self.currentDetectionState = detector.currentState
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[LocationTrackingManager] Error de CoreLocation: \(error.localizedDescription)")
    }
}
