import Foundation
import CoreLocation
import SwiftUI
import SwiftData
import WatchConnectivity
import StayTrackCore

/// ViewModel principal de la aplicación StayTrack para iOS.
///
/// Implementa las reglas de dominio fundamentales de StayTrack:
/// 1. Sincronización con Apple Watch:
///    - Receptor de payloads mediante WatchConnectivity.
///    - Upsert atómico por UUID para Places, Visits y MovementSamples.
///    - Los datos del reloj tienen prioridad absoluta.
///    - Aplica la reconciliación de StayTrackCore cuando se detectan visitas solapadas.
/// 2. Detección propia en modo respaldo:
///    - El iPhone registra estancias con origen `phone` ÚNICAMENTE si el Apple Watch
///      no está conectado ni alcanzable.
///    - Si el iPhone quedó estático mientras el usuario se movía con el reloj puesto,
///      prevalece el reloj y se recorta/descarta la estancia ficticia del teléfono.
/// 3. Gestión integral de lugares, favoritos y estancias históricas.
@MainActor
public final class iOSTrackingViewModel: NSObject, ObservableObject {
    // MARK: - Estado Publicado
    @Published public var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published public var isWatchConnected: Bool = false
    @Published public var isPhoneBackupTrackingActive: Bool = false
    @Published public var currentPhoneStayDescription: String = "Monitorizando en reposo"
    @Published public var lastKnownLocation: Coordinate?

    @Published public var allPlaces: [Place] = []
    @Published public var favoritePlaces: [Place] = []
    @Published public var allVisits: [Visit] = []
    @Published public var movementSamples: [MovementSample] = []

    // MARK: - Componentes de Dominio
    private let locationManager = CLLocationManager()
    private var detector: AnchorZoneDetector
    public let connectivityManager = WatchConnectivityManager.shared

    private var modelContext: ModelContext?
    private var isWatchReachableTimer: Timer?

    public override init() {
        self.detector = AnchorZoneDetector(
            configuration: AnchorZoneDetector.Configuration(
                detectionRadius: 75.0,
                minStayDuration: 120.0,
                maxAccuracyThreshold: 50.0,
                sustainedExitDuration: 60.0,
                consecutiveExitThreshold: 3
            )
        )
        super.init()

        locationManager.delegate = self
        self.authorizationStatus = locationManager.authorizationStatus
        setupLocationManager()
        setupConnectivity()
        startWatchReachabilityMonitoring()
    }

    // MARK: - Inicialización de Contexto SwiftData

    public func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadLocalData()
    }

    private func setupLocationManager() {
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 15.0
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.activityType = .other
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = false
    }

    private func setupConnectivity() {
        connectivityManager.onPayloadReceived = { [weak self] payload in
            Task { @MainActor in
                self?.handleIncomingWatchPayload(payload)
            }
        }
    }

    public func requestAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    // MARK: - Modo Respaldo: Gestión Inteligente de Detección

    private func startWatchReachabilityMonitoring() {
        self.isWatchReachableTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.evaluateWatchPresence()
            }
        }
        evaluateWatchPresence()
    }

    /// Evalúa si el Apple Watch está enlazado y alcanzable
    public func evaluateWatchPresence() {
        let session = WCSession.isSupported() ? WCSession.default : nil
        let reachable = session?.isReachable ?? false
        let paired = session?.isPaired ?? false
        let installed = session?.isWatchAppInstalled ?? false

        let watchIsActive = reachable && paired && installed
        self.isWatchConnected = watchIsActive

        // Regla de Dominio: El iPhone rastrea SOLO si el Watch no está disponible
        if watchIsActive {
            if isPhoneBackupTrackingActive {
                stopPhoneBackupTracking()
            }
        } else {
            if !isPhoneBackupTrackingActive && (authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse) {
                startPhoneBackupTracking()
            }
        }
    }

    private func startPhoneBackupTracking() {
        locationManager.startUpdatingLocation()
        isPhoneBackupTrackingActive = true
        currentPhoneStayDescription = "Modo respaldo activo (Watch desconectado)"
    }

    private func stopPhoneBackupTracking() {
        locationManager.stopUpdatingLocation()
        isPhoneBackupTrackingActive = false
        currentPhoneStayDescription = "En reposo (Prioridad Apple Watch)"
        _ = detector.forceCloseActiveVisit()
    }

    // MARK: - Detección de Ubicación en iPhone

    private func processPhoneLocationUpdate(_ location: CLLocation) {
        guard isPhoneBackupTrackingActive else { return }
        guard location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= detector.configuration.maxAccuracyThreshold else {
            return
        }

        let coord = Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        self.lastKnownLocation = coord

        let sample = LocationSample(
            coordinate: coord,
            horizontalAccuracy: location.horizontalAccuracy,
            timestamp: location.timestamp
        )

        if let event = detector.process(sample: sample) {
            switch event {
            case .visitStarted(let anchor, _, _):
                if let matched = PlaceMatcher.findBestMatchingPlace(for: anchor, in: allPlaces) {
                    currentPhoneStayDescription = "Parado en \(matched.nombre.isEmpty ? "Lugar detectado" : matched.nombre)"
                } else {
                    currentPhoneStayDescription = "Zona en observación (iPhone)"
                }

            case .visitEnded(let anchor, let arrivalDate, let departureDate, let accuracy):
                handlePhoneVisitClosed(anchor: anchor, arrival: arrivalDate, departure: departureDate, accuracy: accuracy)

            case .readingFiltered:
                break
            }
        }
    }

    private func handlePhoneVisitClosed(anchor: Coordinate, arrival: Date, departure: Date, accuracy: Double) {
        guard let context = modelContext else { return }

        // Crear visita con origen phone
        let visit = Visit(
            id: UUID(),
            inicio: arrival,
            fin: departure,
            origen: .phone,
            coordenadaAncla: anchor,
            precision: accuracy
        )

        let assigned = PlaceMatcher.assignPlace(to: visit, in: &allPlaces)
        context.insert(assigned)
        context.insert(visit)

        do {
            try context.save()
            loadLocalData()
        } catch {
            print("[iOSTrackingViewModel] Error al guardar visita de respaldo de iPhone: \(error)")
        }
    }

    // MARK: - Sincronización y Reconciliación con Apple Watch

    public func handleIncomingWatchPayload(_ payload: SyncPayload) {
        guard let context = modelContext else { return }

        // 1. Upsert de Places
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
                existing.fechaModificacion = pDTO.updatedAt
            } else {
                let newPlace = pDTO.toModel()
                context.insert(newPlace)
            }
        }

        // 2. Upsert de Visits entrantes del reloj
        var incomingWatchVisits: [VisitDTO] = []
        for vDTO in payload.visits {
            incomingWatchVisits.append(vDTO)
            if let existing = allVisits.first(where: { $0.id == vDTO.id }) {
                existing.inicio = vDTO.startDate
                existing.fin = vDTO.endDate
                existing.placeId = vDTO.placeId
                existing.origen = vDTO.source
                existing.coordenadaAncla = vDTO.anchorCoordinate
                existing.precision = vDTO.accuracy
                existing.fechaModificacion = vDTO.updatedAt
            } else {
                let newVisit = vDTO.toModel()
                context.insert(newVisit)
            }
        }

        // 3. Upsert de MovementSamples
        for mDTO in payload.movementSamples {
            if !movementSamples.contains(where: { $0.id == mDTO.id }) {
                let newSample = MovementSample(
                    id: mDTO.id,
                    dispositivo: mDTO.device,
                    inicio: mDTO.startDate,
                    fin: mDTO.endDate
                )
                context.insert(newSample)
            }
        }

        do {
            try context.save()
            loadLocalData()

            // 4. Regla de Oro: Reconciliación si el iPhone estuvo estático mientras el Watch se movió
            reconcileVisitsAfterSync(watchVisits: incomingWatchVisits, watchMovements: payload.movementSamples)
        } catch {
            print("[iOSTrackingViewModel] Error durante upsert de WatchConnectivity: \(error)")
        }
    }

    /// Ejecuta la reconciliación de estancias cuando hay actividad dominante del reloj
    private func reconcileVisitsAfterSync(watchVisits: [VisitDTO], watchMovements: [MovementSampleDTO]) {
        guard let context = modelContext else { return }

        // Extraer visitas registradas por el teléfono
        let phoneVisits = allVisits.filter { $0.origen == .phone }
        guard !phoneVisits.isEmpty else { return }

        let phoneDTOs = phoneVisits.map { VisitDTO(from: $0) }
        let allWatchMovementDTOs = movementSamples.filter { $0.dispositivo == .watch }.map { MovementSampleDTO(from: $0) }

        let reconciled = VisitReconciler.reconcile(
            iphoneVisits: phoneDTOs,
            watchVisits: watchVisits,
            watchMovements: allWatchMovementDTOs
        )

        // Actualizar o descartar visitas del teléfono en SwiftData
        let survivingPhoneIds = Set(reconciled.filter { $0.source == .phone }.map(\.id))

        for pv in phoneVisits {
            if !survivingPhoneIds.contains(pv.id) {
                // Totalmente solapada -> se descarta en favor del reloj
                context.delete(pv)
            } else if let matchingReconciled = reconciled.first(where: { $0.id == pv.id }) {
                // Recortada parcialmente -> actualizar fechas
                pv.inicio = matchingReconciled.startDate
                pv.fin = matchingReconciled.endDate
                pv.fechaModificacion = Date()
            }
        }

        do {
            try context.save()
            loadLocalData()
        } catch {
            print("[iOSTrackingViewModel] Error al persistir reconciliación: \(error)")
        }
    }

    // MARK: - Gestión de Lugares y Favoritos

    public func addCurrentLocationAsFavorite(name: String, category: PlaceCategory, radius: Double = 75.0) {
        guard let coord = lastKnownLocation else { return }
        createPlace(
            name: name,
            category: category,
            radius: radius,
            isFavorite: true,
            coordinate: coord
        )
    }

    public func createPlace(
        name: String,
        category: PlaceCategory,
        radius: Double = 75.0,
        isFavorite: Bool = false,
        coordinate: Coordinate,
        customCategoryName: String? = nil,
        icon: String? = nil
    ) {
        guard let context = modelContext else { return }

        let newPlace = Place(
            id: UUID(),
            nombre: name,
            latitud: coordinate.latitude,
            longitud: coordinate.longitude,
            radio: radius,
            isFavorite: isFavorite,
            categoria: category,
            nombrePersonalizadoCategoria: customCategoryName,
            icono: icon ?? category.defaultIcon
        )

        context.insert(newPlace)

        do {
            try context.save()
            loadLocalData()

            // Enviar al reloj
            let payload = SyncPayload(
                places: [PlaceDTO(from: newPlace)],
                visits: [],
                movementSamples: [],
                source: .phone
            )
            connectivityManager.sendPayload(payload)
        } catch {
            print("[iOSTrackingViewModel] Error al crear lugar: \(error)")
        }
    }

    public func editPlace(
        place: Place,
        name: String,
        category: PlaceCategory,
        radius: Double,
        isFavorite: Bool,
        icon: String? = nil
    ) {
        guard let context = modelContext else { return }

        place.nombre = name
        place.categoria = category
        place.radio = radius
        place.isFavorite = isFavorite
        if let ico = icon {
            place.icono = ico
        }
        place.fechaModificacion = Date()

        do {
            try context.save()
            loadLocalData()

            let payload = SyncPayload(
                places: [PlaceDTO(from: place)],
                visits: [],
                movementSamples: [],
                source: .phone
            )
            connectivityManager.sendPayload(payload)
        } catch {
            print("[iOSTrackingViewModel] Error al editar lugar: \(error)")
        }
    }

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
                source: .phone
            )
            connectivityManager.sendPayload(payload)
        } catch {
            print("[iOSTrackingViewModel] Error al alternar favorito: \(error)")
        }
    }

    public func deletePlace(place: Place) {
        guard let context = modelContext else { return }
        context.delete(place)

        do {
            try context.save()
            loadLocalData()
        } catch {
            print("[iOSTrackingViewModel] Error al eliminar lugar: \(error)")
        }
    }

    /// Fusiona el lugar origen dentro del lugar destino, actualizando todo el histórico de visitas
    public func mergePlaces(source: Place, into target: Place) {
        guard let context = modelContext else { return }

        PlaceManager.mergePlaces(source: source, into: target, places: &allPlaces, visitas: &allVisits)
        context.delete(source)

        do {
            try context.save()
            loadLocalData()

            // Sincronizar actualización con el reloj
            let affectedVisits = allVisits.filter { $0.placeId == target.id }.map { VisitDTO(from: $0) }
            let payload = SyncPayload(
                places: [PlaceDTO(from: target)],
                visits: affectedVisits,
                movementSamples: [],
                source: .phone
            )
            connectivityManager.sendPayload(payload)
        } catch {
            print("[iOSTrackingViewModel] Error al fusionar lugares: \(error)")
        }
    }

    // MARK: - Gestión Manual de Estancias (Visitas)

    public func editVisit(visit: Visit, newPlace: Place?, newStart: Date, newEnd: Date?) {
        guard let context = modelContext else { return }

        visit.place = newPlace
        visit.placeId = newPlace?.id
        visit.inicio = newStart
        visit.fin = newEnd
        visit.fechaModificacion = Date()

        do {
            try context.save()
            loadLocalData()

            let payload = SyncPayload(
                places: [],
                visits: [VisitDTO(from: visit)],
                movementSamples: [],
                source: .phone
            )
            connectivityManager.sendPayload(payload)
        } catch {
            print("[iOSTrackingViewModel] Error al editar visita: \(error)")
        }
    }

    public func deleteVisit(visit: Visit) {
        guard let context = modelContext else { return }
        context.delete(visit)

        do {
            try context.save()
            loadLocalData()
        } catch {
            print("[iOSTrackingViewModel] Error al eliminar visita: \(error)")
        }
    }

    /// Divide una estancia en dos visitas contiguas separadas por `splitDate`
    public func splitVisit(visit: Visit, splitDate: Date) {
        guard let context = modelContext else { return }
        let originalStart = visit.inicio
        let originalEnd = visit.fin ?? Date()

        guard splitDate > originalStart && splitDate < originalEnd else { return }

        // Modificar primer tramo
        visit.fin = splitDate
        visit.fechaModificacion = Date()

        // Crear segundo tramo
        let secondSegment = Visit(
            id: UUID(),
            placeId: visit.placeId,
            place: visit.place,
            inicio: splitDate,
            fin: originalEnd,
            origen: visit.origen,
            coordenadaAncla: visit.coordenadaAncla,
            precision: visit.precision,
            fechaModificacion: Date()
        )
        context.insert(secondSegment)

        do {
            try context.save()
            loadLocalData()

            let payload = SyncPayload(
                places: [],
                visits: [VisitDTO(from: visit), VisitDTO(from: secondSegment)],
                movementSamples: [],
                source: .phone
            )
            connectivityManager.sendPayload(payload)
        } catch {
            print("[iOSTrackingViewModel] Error al dividir visita: \(error)")
        }
    }

    // MARK: - Carga Local de Datos

    public func loadLocalData() {
        guard let context = modelContext else { return }

        do {
            let placeDesc = FetchDescriptor<Place>(sortBy: [SortDescriptor(\.fechaCreacion, order: .reverse)])
            self.allPlaces = try context.fetch(placeDesc)
            self.favoritePlaces = self.allPlaces.filter { $0.isFavorite }

            let visitDesc = FetchDescriptor<Visit>(sortBy: [SortDescriptor(\.inicio, order: .reverse)])
            self.allVisits = try context.fetch(visitDesc)

            let sampleDesc = FetchDescriptor<MovementSample>(sortBy: [SortDescriptor(\.inicio, order: .reverse)])
            self.movementSamples = try context.fetch(sampleDesc)
        } catch {
            print("[iOSTrackingViewModel] Error al cargar datos locales: \(error)")
        }
    }

    deinit {
        isWatchReachableTimer?.invalidate()
    }
}

// MARK: - CLLocationManagerDelegate
extension iOSTrackingViewModel: @preconcurrency CLLocationManagerDelegate {
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.authorizationStatus = manager.authorizationStatus
        evaluateWatchPresence()
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        processPhoneLocationUpdate(latest)
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[iOSTrackingViewModel] Error en CoreLocation: \(error.localizedDescription)")
    }
}
