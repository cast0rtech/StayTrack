import Foundation
import CoreLocation
import SwiftUI
import SwiftData
import WatchKit
import StayTrackCore

/// ViewModel principal de la aplicación StayTrack Watch.
///
/// Arquitectura y decisiones no triviales:
/// 1. Funcionamiento 100% Autónomo:
///    - Registra estancias y muestras de movimiento localmente en SwiftData del Apple Watch.
///    - Funciona sin iPhone conectado, apagado o desemparejado.
/// 2. Ahorro riguroso de batería:
///    - Alterna la precisión del GPS: mientras el usuario se desplaza, opera con baja precisión
///      (kCLLocationAccuracyHundredMeters) para no drenar la batería.
///    - Solo al detectar una desaceleración sostenida (o inactividad vía WatchMotionDetector), eleva
///      la precisión a kCLLocationAccuracyNearestTenMeters para confirmar el anclaje de 2 minutos.
/// 3. Lógica pura compartida:
///    - Utiliza AnchorZoneDetector y PlaceMatcher directamente de StayTrackCore sin duplicar modelos ni reglas.
/// 4. Sincronización transparente:
///    - Encola en segundo plano mediante WCSession.transferUserInfo todas las visitas, lugares y muestras de movimiento.
@MainActor
public final class WatchTrackingViewModel: NSObject, ObservableObject {
    // MARK: - Estado Publicado para la UI
    @Published public var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published public var isTrackingActive: Bool = false
    @Published public var isStationary: Bool = false
    @Published public var currentStateDescription: String = "Iniciando..."
    @Published public var currentPlaceName: String = "En movimiento"
    @Published public var currentCategory: PlaceCategory = .otro
    @Published public var currentVisitSince: Date? = nil
    @Published public var elapsedTimeString: String = "0m"

    @Published public var detectionRadius: Double = 75.0 {
        didSet {
            detector.configuration.detectionRadius = detectionRadius
            UserDefaults.standard.set(detectionRadius, forKey: "detectionRadius")
        }
    }

    @Published public var recentVisits: [Visit] = []
    @Published public var allPlaces: [Place] = []
    @Published public var showCheckInCelebration: Bool = false
    @Published public var lastCelebratedVisitDescription: String = ""

    // MARK: - Componentes de Dominio y Sensores
    private let locationManager = CLLocationManager()
    private var detector: AnchorZoneDetector
    public let motionDetector = WatchMotionDetector()
    public let backgroundSessionManager = WatchBackgroundSessionManager.shared
    public let connectivityManager = WatchConnectivityManager.shared

    private var modelContext: ModelContext?
    private var timer: Timer?
    private var activeVisitCandidateAnchor: Coordinate?
    private var activeVisitStartDate: Date?
    private var lastValidCoordinate: Coordinate?

    public override init() {
        let savedRadius = UserDefaults.standard.double(forKey: "detectionRadius")
        let initialRadius = savedRadius > 0 ? savedRadius : 75.0
        self.detectionRadius = initialRadius

        self.detector = AnchorZoneDetector(
            configuration: AnchorZoneDetector.Configuration(
                detectionRadius: initialRadius,
                minStayDuration: 120.0, // 2 minutos obligatorios
                maxAccuracyThreshold: 50.0,
                sustainedExitDuration: 60.0,
                consecutiveExitThreshold: 3
            )
        )

        super.init()

        locationManager.delegate = self
        self.authorizationStatus = locationManager.authorizationStatus
        setupLocationManager()
        setupMotionCallbacks()
        setupConnectivityCallbacks()
        startLiveTimer()
    }

    // MARK: - Configuración de SwiftData Context

    public func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadLocalData()
    }

    private func setupLocationManager() {
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters // Modo ahorro por defecto
        locationManager.distanceFilter = 25.0
        #if !os(watchOS)
        locationManager.pausesLocationUpdatesAutomatically = true
        #endif
    }

    private func setupMotionCallbacks() {
        motionDetector.onMovementSampleCompleted = { [weak self] sampleDTO in
            Task { @MainActor in
                self?.handleCompletedMovementSample(sampleDTO)
            }
        }
    }

    private func setupConnectivityCallbacks() {
        connectivityManager.onPayloadReceived = { [weak self] payload in
            Task { @MainActor in
                self?.handleIncomingSyncPayload(payload)
            }
        }
    }

    // MARK: - Ciclo de Vida del Seguimiento

    public func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    public func startTracking() {
        guard !isTrackingActive else { return }

        backgroundSessionManager.startBackgroundSession()
        motionDetector.startMonitoring()
        locationManager.startUpdatingLocation()

        isTrackingActive = true
        currentStateDescription = "Buscando ubicación..."
    }

    public func stopTracking() {
        guard isTrackingActive else { return }

        locationManager.stopUpdatingLocation()
        motionDetector.stopMonitoring()
        backgroundSessionManager.stopBackgroundSession()

        isTrackingActive = false
        currentStateDescription = "Seguimiento pausado"
    }

    // MARK: - Detección y Procesamiento de Eventos

    private func processLocationUpdate(_ location: CLLocation) {
        // Filtrar lecturas de mala precisión (> 50 m o negativa)
        guard location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= detector.configuration.maxAccuracyThreshold else {
            return
        }

        let coord = Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        self.lastValidCoordinate = coord

        let sample = LocationSample(
            coordinate: coord,
            horizontalAccuracy: location.horizontalAccuracy,
            timestamp: location.timestamp
        )

        // Adaptar precisión del GPS para ahorro de batería
        if motionDetector.isMoving {
            // Si el usuario camina o se desplaza rápido, mantenemos precisión relajada
            if locationManager.desiredAccuracy != kCLLocationAccuracyHundredMeters {
                locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
                locationManager.distanceFilter = 35.0
            }
        } else {
            // Si está quieto o desacelerando, aumentamos precisión para confirmar check-in preciso
            if locationManager.desiredAccuracy != kCLLocationAccuracyNearestTenMeters {
                locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
                locationManager.distanceFilter = 10.0
            }
        }

        // Evaluar muestra con la lógica pura de StayTrackCore
        if let event = detector.process(sample: sample) {
            switch event {
            case .visitStarted(let anchor, let arrivalDate, _):
                self.isStationary = true
                self.activeVisitCandidateAnchor = anchor
                self.activeVisitStartDate = arrivalDate
                self.currentVisitSince = arrivalDate

                // Buscar si ya coincide con algún lugar conocido
                if let matched = PlaceMatcher.findBestMatchingPlace(for: anchor, in: allPlaces) {
                    self.currentPlaceName = matched.nombre.isEmpty ? "Lugar detectado" : matched.nombre
                    self.currentCategory = matched.categoria
                } else {
                    self.currentPlaceName = "Zona en observación"
                    self.currentCategory = .otro
                }
                self.currentStateDescription = "Parado en \(currentPlaceName)"

            case .visitEnded(let anchor, let arrivalDate, let departureDate, let accuracy):
                handleVisitClosed(anchor: anchor, arrivalDate: arrivalDate, departureDate: departureDate, accuracy: accuracy)

            case .readingFiltered:
                break
            }
        } else {
            if !isStationary {
                self.currentStateDescription = motionDetector.isMoving ? "En movimiento (\(motionDetector.currentActivityTitle))" : "En desplazamiento"
                self.currentPlaceName = "En movimiento"
            }
        }
    }

    private func handleVisitClosed(anchor: Coordinate, arrivalDate: Date, departureDate: Date, accuracy: Double) {
        self.isStationary = false
        self.currentVisitSince = nil
        self.currentStateDescription = "En movimiento"
        self.currentPlaceName = "En movimiento"
        self.currentCategory = .otro

        guard let context = modelContext else { return }

        // 1. Crear Visit en SwiftData
        let visit = Visit(
            id: UUID(),
            inicio: arrivalDate,
            fin: departureDate,
            origen: .watch,
            coordenadaAncla: anchor,
            precision: accuracy
        )

        // 2. Asignar al Place más idóneo (prioridad para favoritos) o crear Place sin nombre
        let assignedPlace = PlaceMatcher.assignPlace(to: visit, in: &allPlaces, defaultRadius: detectionRadius)

        context.insert(assignedPlace)
        context.insert(visit)

        do {
            try context.save()
            loadLocalData()

            // 3. Notificar UI con micro-animación de éxito y retroalimentación háptica en la muñeca
            let durationStr = StayTrackUtils.formatDuration(departureDate.timeIntervalSince(arrivalDate))
            let placeName = assignedPlace.nombre.isEmpty ? "Zona registrada" : assignedPlace.nombre
            self.lastCelebratedVisitDescription = "\(placeName) (\(durationStr))"
            triggerCelebration()

            // 4. Sincronizar hacia el iPhone mediante WatchConnectivity
            let syncPayload = SyncPayload(
                places: [PlaceDTO(from: assignedPlace)],
                visits: [VisitDTO(from: visit)],
                movementSamples: [],
                source: .watch
            )
            connectivityManager.sendPayload(syncPayload)
        } catch {
            print("[WatchTrackingViewModel] Error al guardar visita en SwiftData: \(error)")
        }
    }

    private func handleCompletedMovementSample(_ sampleDTO: MovementSampleDTO) {
        guard let context = modelContext else { return }

        let sample = MovementSample(
            id: sampleDTO.id,
            dispositivo: .watch,
            inicio: sampleDTO.startDate,
            fin: sampleDTO.endDate
        )
        context.insert(sample)

        do {
            try context.save()

            // Encolar muestra de movimiento del reloj para reconciliación en iPhone
            let payload = SyncPayload(
                places: [],
                visits: [],
                movementSamples: [sampleDTO],
                source: .watch
            )
            connectivityManager.sendPayload(payload)
        } catch {
            print("[WatchTrackingViewModel] Error al persistir MovementSample: \(error)")
        }
    }

    // MARK: - Gestión de Favoritos

    /// Crea un favorito directamente desde la estancia o ubicación actual
    public func createFavoriteFromCurrent(
        name: String,
        category: PlaceCategory,
        icon: String? = nil,
        radius: Double? = nil
    ) {
        guard let context = modelContext else { return }

        let targetCoordinate = activeVisitCandidateAnchor ?? lastValidCoordinate ?? Coordinate(latitude: 0, longitude: 0)
        let targetRadius = radius ?? detectionRadius

        let favoritePlace = Place(
            id: UUID(),
            nombre: name,
            latitud: targetCoordinate.latitude,
            longitud: targetCoordinate.longitude,
            radio: targetRadius,
            isFavorite: true,
            categoria: category,
            nombrePersonalizadoCategoria: nil,
            icono: icon ?? category.defaultIcon
        )

        allPlaces.append(favoritePlace)
        context.insert(favoritePlace)

        // Si hay una estancia activa, vincularla al nuevo favorito
        if isStationary {
            self.currentPlaceName = name
            self.currentCategory = category
            self.currentStateDescription = "Parado en \(name)"
        }

        do {
            try context.save()
            loadLocalData()

            // Sincronizar el nuevo favorito con iPhone
            let payload = SyncPayload(
                places: [PlaceDTO(from: favoritePlace)],
                visits: [],
                movementSamples: [],
                source: .watch
            )
            connectivityManager.sendPayload(payload)

            triggerCelebration()
        } catch {
            print("[WatchTrackingViewModel] Error al guardar favorito: \(error)")
        }
    }

    /// Alterna el estado de favorito de un lugar
    public func toggleFavorite(place: Place) {
        guard let context = modelContext else { return }
        place.isFavorite.toggle()
        place.fechaModificacion = Date()

        do {
            try context.save()
            loadLocalData()

            let payload = SyncPayload(
                places: [PlaceDTO(from: place)],
                visits: [],
                movementSamples: [],
                source: .watch
            )
            connectivityManager.sendPayload(payload)
        } catch {
            print("[WatchTrackingViewModel] Error al actualizar favorito: \(error)")
        }
    }

    /// Renombra un lugar y actualiza las referencias
    public func renamePlace(place: Place, newName: String) {
        guard let context = modelContext else { return }
        PlaceManager.renamePlace(place: place, nuevoNombre: newName, visitas: recentVisits)

        do {
            try context.save()
            loadLocalData()

            let payload = SyncPayload(
                places: [PlaceDTO(from: place)],
                visits: recentVisits.filter { $0.placeId == place.id }.map { VisitDTO(from: $0) },
                movementSamples: [],
                source: .watch
            )
            connectivityManager.sendPayload(payload)
        } catch {
            print("[WatchTrackingViewModel] Error al renombrar lugar: \(error)")
        }
    }

    // MARK: - Carga Local y Sincronización Entrante

    public func loadLocalData() {
        guard let context = modelContext else { return }

        do {
            var placeDescriptor = FetchDescriptor<Place>(sortBy: [SortDescriptor(\.fechaCreacion, order: .reverse)])
            placeDescriptor.fetchLimit = 50
            self.allPlaces = try context.fetch(placeDescriptor)

            var visitDescriptor = FetchDescriptor<Visit>(sortBy: [SortDescriptor(\.inicio, order: .reverse)])
            visitDescriptor.fetchLimit = 20
            self.recentVisits = try context.fetch(visitDescriptor)
        } catch {
            print("[WatchTrackingViewModel] Error al cargar datos de SwiftData: \(error)")
        }
    }

    private func handleIncomingSyncPayload(_ payload: SyncPayload) {
        guard let context = modelContext else { return }

        // Upsert de Places recibidos desde iPhone
        for pDTO in payload.places {
            if let existing = allPlaces.first(where: { $0.id == pDTO.id }) {
                existing.nombre = pDTO.name
                existing.latitud = pDTO.latitude
                existing.longitud = pDTO.longitude
                existing.radio = pDTO.radius
                existing.isFavorite = pDTO.isFavorite
                existing.categoria = pDTO.category
                existing.nombrePersonalizadoCategoria = pDTO.customCategoryName
                existing.icono = pDTO.icon
            } else {
                let newPlace = pDTO.toModel()
                context.insert(newPlace)
            }
        }

        // Upsert de Visits
        for vDTO in payload.visits {
            if let existing = recentVisits.first(where: { $0.id == vDTO.id }) {
                existing.inicio = vDTO.startDate
                existing.fin = vDTO.endDate
                existing.placeId = vDTO.placeId
            } else {
                let newVisit = vDTO.toModel()
                context.insert(newVisit)
            }
        }

        do {
            try context.save()
            loadLocalData()
        } catch {
            print("[WatchTrackingViewModel] Error al integrar SyncPayload entrante: \(error)")
        }
    }

    // MARK: - Micro-Animación y Temporizador

    private func triggerCelebration() {
        WKInterfaceDevice.current().play(.success)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            self.showCheckInCelebration = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            withAnimation(.easeOut(duration: 0.5)) {
                self?.showCheckInCelebration = false
            }
        }
    }

    private func startLiveTimer() {
        self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if let since = self.currentVisitSince {
                    let elapsed = Date().timeIntervalSince(since)
                    self.elapsedTimeString = StayTrackUtils.formatDuration(elapsed)
                } else {
                    self.elapsedTimeString = "0m"
                }
            }
        }
    }

    deinit {
        timer?.invalidate()
    }
}

// MARK: - CLLocationManagerDelegate
extension WatchTrackingViewModel: @preconcurrency CLLocationManagerDelegate {
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            startTracking()
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        processLocationUpdate(latest)
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[WatchTrackingViewModel] Error de ubicación: \(error.localizedDescription)")
    }
}
