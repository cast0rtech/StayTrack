import Foundation
import SwiftUI
import SwiftData
import CoreLocation
import MapKit
import StayTrackCore

public struct CategoryTimeStat: Identifiable {
    public var id: String { category.rawValue }
    public let category: PlaceCategory
    public let totalSeconds: TimeInterval
    public var hours: Double { totalSeconds / 3600.0 }
}

public struct PlaceTimeStat: Identifiable {
    public var id: UUID
    public let placeName: String
    public let category: PlaceCategory
    public let totalSeconds: TimeInterval
    public var hours: Double { totalSeconds / 3600.0 }
}

/// ViewModel principal para StayTrack iOS.
/// Gestiona la sincronización con Apple Watch, reconciliación de datos,
/// edición de lugares, estadísticas para Swift Charts y exportación multiformato.
@MainActor
public final class iOSTrackingViewModel: ObservableObject {
    @Published public var places: [Place] = []
    @Published public var visits: [Visit] = []
    @Published public var currentPlace: Place?
    @Published public var activeVisit: Visit?
    @Published public var isTrackingActive: Bool = false
    @Published public var trackingStatusText: String = "Preparado"
    @Published public var elapsedTimeString: String = "00:00"
    @Published public var isSyncing: Bool = false
    @Published public var lastSyncDate: Date?
    @Published public var watchSyncStateText: String = "Buscando Apple Watch..."
    @Published public var isWatchConnected: Bool = false
    @Published public var isExporting: Bool = false
    @Published public var exportedFileURL: URL?
    @Published public var exportedMapImage: PlatformImage?

    public let locationTracker: LocationTrackingManager
    public let motionManager: MotionActivityManager
    private var modelContext: ModelContext?
    private var activeTimer: Timer?

    public init() {
        self.locationTracker = LocationTrackingManager()
        self.motionManager = MotionActivityManager()
        setupCallbacks()
    }

    public func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadLocalData()
        seedInitialPlacesIfEmpty()
        startActiveTimer()
        startTracking()
    }

    private func setupCallbacks() {
        locationTracker.onDetectionEvent = { [weak self] event in
            guard let self = self else { return }
            self.handleLocationDetectionEvent(event)
        }

        #if canImport(WatchConnectivity)
        WatchConnectivityManager.shared.onPayloadReceived = { [weak self] payload in
            guard let self = self else { return }
            self.applyIncomingWatchPayload(payload)
        }
        #endif
    }

    // MARK: - Seguimiento de Ubicación

    public func startTracking() {
        locationTracker.requestAuthorization()
        locationTracker.startTracking()
        motionManager.startTrackingActivity()
        isTrackingActive = true
        trackingStatusText = "Registrando en segundo plano"
    }

    public func stopTracking() {
        locationTracker.stopTracking()
        motionManager.stopTrackingActivity()
        isTrackingActive = false
        trackingStatusText = "Seguimiento pausado"
    }

    private func handleLocationDetectionEvent(_ event: DetectionEvent) {
        // Si el Watch está conectado y activo, priorizamos los datos del Watch
        #if canImport(WatchConnectivity)
        if WatchConnectivityManager.shared.isReachable {
            print("[iOSTracking] Watch conectado: delegando prioridad al Apple Watch.")
        }
        #endif

        guard let context = modelContext else { return }

        switch event {
        case .visitStarted(let anchor, let arrivalDate):
            let matchedPlace = PlaceMatcher.findBestMatchingPlace(for: anchor, in: self.places)

            let newVisit = Visit(
                id: UUID(),
                placeId: matchedPlace?.id,
                place: matchedPlace,
                latitude: anchor.latitude,
                longitude: anchor.longitude,
                arrivalDate: arrivalDate,
                departureDate: nil,
                deviceSource: .iphone,
                isMovingDetected: motionManager.isMoving,
                createdAt: Date(),
                updatedAt: Date()
            )

            context.insert(newVisit)
            try? context.save()

            self.activeVisit = newVisit
            self.currentPlace = matchedPlace
            self.trackingStatusText = matchedPlace != nil ? "En \(matchedPlace!.name)" : "En Punto Ancla"
            loadLocalData()
            syncWithWatch()

        case .visitEnded(_, _, let departureDate):
            if let active = activeVisit {
                active.departureDate = departureDate
                active.updatedAt = Date()
                try? context.save()
            }
            self.activeVisit = nil
            self.currentPlace = nil
            self.trackingStatusText = "En desplazamiento"
            loadLocalData()
            syncWithWatch()

        case .readingFiltered(let reason, _):
            print("[iOSTracking] Lectura GPS filtrada: \(reason)")
        }
    }

    // MARK: - Carga de Datos y Semilla Inicial

    public func loadLocalData() {
        guard let context = modelContext else { return }

        do {
            let placeDescriptor = FetchDescriptor<Place>(sortBy: [SortDescriptor(\.name)])
            self.places = try context.fetch(placeDescriptor)

            let visitDescriptor = FetchDescriptor<Visit>(sortBy: [SortDescriptor(\.arrivalDate, order: .reverse)])
            self.visits = try context.fetch(visitDescriptor)

            self.activeVisit = visits.first { $0.isOngoing }
            if let active = activeVisit {
                self.currentPlace = active.place
            }

            #if canImport(WatchConnectivity)
            self.isWatchConnected = WatchConnectivityManager.shared.isReachable
            self.watchSyncStateText = isWatchConnected ? "Apple Watch conectado (Prioridad Activa)" : "Modo Autónomo iPhone"
            #endif
        } catch {
            print("[iOSTracking] Error al cargar SwiftData: \(error)")
        }
    }

    private func seedInitialPlacesIfEmpty() {
        guard let context = modelContext, places.isEmpty else { return }

        let demoPlaces = [
            Place(name: "Casa", isFavorite: true, category: .home, icon: "house.fill", latitude: 40.416775, longitude: -3.703790, radius: 75.0),
            Place(name: "Oficina Central", isFavorite: true, category: .work, icon: "briefcase.fill", latitude: 40.450000, longitude: -3.690000, radius: 75.0),
            Place(name: "Gimnasio Metropolis", isFavorite: false, category: .workout, icon: "figure.run", latitude: 40.428000, longitude: -3.700000, radius: 50.0),
            Place(name: "Centro de Salud", isFavorite: false, category: .medical, icon: "cross.case.fill", latitude: 40.435000, longitude: -3.715000, radius: 100.0)
        ]

        for p in demoPlaces {
            context.insert(p)
        }

        // Crear una estancia previa de demostración
        let now = Date()
        let sampleVisit = Visit(
            id: UUID(),
            placeId: demoPlaces[0].id,
            place: demoPlaces[0],
            latitude: demoPlaces[0].latitude,
            longitude: demoPlaces[0].longitude,
            arrivalDate: now.addingTimeInterval(-7200),
            departureDate: now.addingTimeInterval(-1800),
            deviceSource: .watch,
            isMovingDetected: false
        )
        context.insert(sampleVisit)

        try? context.save()
        loadLocalData()
    }

    // MARK: - Gestión de Lugares (CRUD)

    public func addPlace(
        name: String,
        category: PlaceCategory,
        icon: String?,
        isFavorite: Bool,
        latitude: Double,
        longitude: Double,
        radius: Double
    ) {
        guard let context = modelContext else { return }

        let newPlace = Place(
            name: name,
            isFavorite: isFavorite,
            category: category,
            icon: icon,
            latitude: latitude,
            longitude: longitude,
            radius: radius
        )
        context.insert(newPlace)
        try? context.save()
        loadLocalData()
        syncWithWatch()
    }

    public func updatePlace(
        place: Place,
        name: String,
        category: PlaceCategory,
        icon: String,
        isFavorite: Bool,
        radius: Double
    ) {
        guard let context = modelContext else { return }
        place.name = name
        place.category = category
        place.icon = icon
        place.isFavorite = isFavorite
        place.radius = radius
        place.updatedAt = Date()
        try? context.save()
        loadLocalData()
        syncWithWatch()
    }

    public func deletePlace(_ place: Place) {
        guard let context = modelContext else { return }
        context.delete(place)
        try? context.save()
        loadLocalData()
        syncWithWatch()
    }

    public func deleteVisit(_ visit: Visit) {
        guard let context = modelContext else { return }
        context.delete(visit)
        try? context.save()
        loadLocalData()
        syncWithWatch()
    }

    // MARK: - Reconciliación y Sincronización WatchConnectivity

    public func syncWithWatch() {
        #if canImport(WatchConnectivity)
        isSyncing = true
        let placesDTO = places.map { PlaceDTO(from: $0) }
        let visitsDTO = visits.map { VisitDTO(from: $0) }

        let payload = SyncPayload(
            places: placesDTO,
            visits: visitsDTO,
            source: .iphone,
            sentAt: Date()
        )

        WatchConnectivityManager.shared.sendPayload(payload)
        self.lastSyncDate = Date()
        self.isSyncing = false
        #endif
    }

    public func applyIncomingWatchPayload(_ payload: SyncPayload) {
        guard let context = modelContext else { return }

        // 1. Reconciliar Lugares
        let localPlacesDTO = places.map { PlaceDTO(from: $0) }
        let reconciledPlaces = PlaceReconciler.reconcile(existing: localPlacesDTO, incoming: payload.places)

        for pDTO in reconciledPlaces {
            if let existing = places.first(where: { $0.id == pDTO.id }) {
                existing.name = pDTO.name
                existing.isFavorite = pDTO.isFavorite
                existing.category = pDTO.category
                existing.icon = pDTO.icon
                existing.latitude = pDTO.latitude
                existing.longitude = pDTO.longitude
                existing.radius = pDTO.radius
                existing.updatedAt = pDTO.updatedAt
            } else {
                let newPlace = Place(
                    id: pDTO.id,
                    name: pDTO.name,
                    isFavorite: pDTO.isFavorite,
                    category: pDTO.category,
                    icon: pDTO.icon,
                    latitude: pDTO.latitude,
                    longitude: pDTO.longitude,
                    radius: pDTO.radius,
                    createdAt: pDTO.createdAt,
                    updatedAt: pDTO.updatedAt
                )
                context.insert(newPlace)
            }
        }

        // 2. Reconciliar Visitas aplicando precedencia del Watch y resolución de dispositivos estáticos
        let localIphoneVisits = visits.filter { $0.deviceSource == .iphone }.map { VisitDTO(from: $0) }
        let incomingWatchVisits = payload.visits.filter { $0.deviceSource == .watch }

        let reconciledVisits = VisitReconciler.reconcile(
            iphoneVisits: localIphoneVisits,
            watchVisits: incomingWatchVisits
        )

        // Limpiar y reemplazar visitas locales según reconciliación
        for visit in visits {
            context.delete(visit)
        }

        for vDTO in reconciledVisits {
            let matchedPlace = vDTO.placeId.flatMap { pid in places.first { $0.id == pid } }
            let v = Visit(
                id: vDTO.id,
                placeId: vDTO.placeId,
                place: matchedPlace,
                latitude: vDTO.latitude,
                longitude: vDTO.longitude,
                arrivalDate: vDTO.arrivalDate,
                departureDate: vDTO.departureDate,
                deviceSource: vDTO.deviceSource,
                isMovingDetected: vDTO.isMovingDetected,
                createdAt: vDTO.createdAt,
                updatedAt: vDTO.updatedAt
            )
            context.insert(v)
        }

        try? context.save()
        loadLocalData()
        self.lastSyncDate = Date()
    }

    // MARK: - Estadísticas para Swift Charts

    public var statsByCategory: [CategoryTimeStat] {
        var dict = [PlaceCategory: TimeInterval]()
        for category in PlaceCategory.allCases {
            dict[category] = 0
        }
        for visit in visits {
            let cat = visit.place?.category ?? .other
            dict[cat, default: 0] += visit.duration
        }
        return dict.map { CategoryTimeStat(category: $0.key, totalSeconds: $0.value) }
            .sorted { $0.totalSeconds > $1.totalSeconds }
    }

    public var statsByPlace: [PlaceTimeStat] {
        var dict = [UUID: (name: String, cat: PlaceCategory, duration: TimeInterval)]()
        for visit in visits {
            if let place = visit.place {
                let current = dict[place.id] ?? (place.name, place.category, 0)
                dict[place.id] = (current.name, current.cat, current.duration + visit.duration)
            } else {
                let unnamedId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
                let current = dict[unnamedId] ?? ("Puntos Ancla", .other, 0)
                dict[unnamedId] = (current.name, current.cat, current.duration + visit.duration)
            }
        }
        return dict.map { PlaceTimeStat(id: $0.key, placeName: $0.value.name, category: $0.value.cat, totalSeconds: $0.value.duration) }
            .sorted { $0.totalSeconds > $1.totalSeconds }
    }

    public var totalTrackedSeconds: TimeInterval {
        return visits.reduce(0) { $0 + $1.duration }
    }

    // MARK: - Exportación

    public func exportFile(format: ExportFormat) -> URL? {
        let placesDTO = places.map { PlaceDTO(from: $0) }
        let visitsDTO = visits.map { VisitDTO(from: $0) }
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "StayTrack_Export_\(Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")).\(format.fileExtension)"
        let fileURL = tempDir.appendingPathComponent(filename)

        var dataToSave: Data?

        switch format {
        case .csv:
            dataToSave = CSVExporter.generateCSVData(visits: visitsDTO, places: placesDTO)
        case .xlsx:
            dataToSave = XLSXExporter.generateXLSXData(visits: visitsDTO, places: placesDTO)
        case .gpx:
            dataToSave = GPXExporter.generateGPXData(places: placesDTO, visits: visitsDTO)
        case .kml:
            dataToSave = KMLExporter.generateKMLData(places: placesDTO, visits: visitsDTO)
        case .mapImage:
            return nil
        }

        guard let data = dataToSave else { return nil }
        do {
            try data.write(to: fileURL)
            self.exportedFileURL = fileURL
            return fileURL
        } catch {
            print("[iOSTracking] Error al exportar archivo: \(error)")
            return nil
        }
    }

    public func exportMapImageSnapshot() async -> PlatformImage? {
        let placesDTO = places.map { PlaceDTO(from: $0) }
        guard !placesDTO.isEmpty else { return nil }
        do {
            let image = try await MapSnapshotGenerator.generateMapSnapshot(places: placesDTO)
            self.exportedMapImage = image
            return image
        } catch {
            print("[iOSTracking] Error al generar captura de mapa: \(error)")
            return nil
        }
    }

    private func startActiveTimer() {
        activeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let active = self.activeVisit else {
                    self?.elapsedTimeString = "00:00"
                    return
                }
                let duration = Date().timeIntervalSince(active.arrivalDate)
                let hours = Int(duration) / 3600
                let minutes = (Int(duration) % 3600) / 60
                let seconds = Int(duration) % 60
                if hours > 0 {
                    self.elapsedTimeString = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
                } else {
                    self.elapsedTimeString = String(format: "%02d:%02d", minutes, seconds)
                }
            }
        }
    }
}
