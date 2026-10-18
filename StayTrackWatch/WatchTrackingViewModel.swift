import Foundation
import SwiftUI
import SwiftData
import CoreLocation
import StayTrackCore

/// ViewModel principal para StayTrack Watch (watchOS).
/// Gestiona la detección local autónoma de estancias, el emparejamiento con lugares
/// y la sincronización con el iPhone.
@MainActor
public final class WatchTrackingViewModel: ObservableObject {
    @Published public var currentPlace: Place?
    @Published public var activeVisit: Visit?
    @Published public var trackingStatusText: String = "Iniciando..."
    @Published public var isTrackingActive: Bool = false
    @Published public var recentVisits: [Visit] = []
    @Published public var places: [Place] = []
    @Published public var detectionRadius: Double = 75.0
    @Published public var elapsedTimeString: String = "00:00"
    @Published public var isSyncing: Bool = false
    @Published public var lastSyncMessage: String = "Pendiente"

    public let locationTracker: LocationTrackingManager
    public let motionManager: MotionActivityManager
    private var modelContext: ModelContext?
    private var timer: Timer?

    public init() {
        self.locationTracker = LocationTrackingManager()
        self.motionManager = MotionActivityManager()
        setupCallbacks()
    }

    public func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadLocalData()
        startActiveTimer()
        startAutonomousTracking()
    }

    private func setupCallbacks() {
        locationTracker.onDetectionEvent = { [weak self] event in
            guard let self = self else { return }
            self.handleDetectionEvent(event)
        }

        #if canImport(WatchConnectivity)
        WatchConnectivityManager.shared.onPayloadReceived = { [weak self] payload in
            guard let self = self else { return }
            self.applyIncomingPayload(payload)
        }
        #endif
    }

    public func startAutonomousTracking() {
        locationTracker.requestAuthorization()
        locationTracker.startTracking()
        motionManager.startTrackingActivity()
        isTrackingActive = true
        trackingStatusText = "Buscando satélites GPS..."
    }

    public func stopAutonomousTracking() {
        locationTracker.stopTracking()
        motionManager.stopTrackingActivity()
        isTrackingActive = false
        trackingStatusText = "Pausado"
        timer?.invalidate()
    }

    private func handleDetectionEvent(_ event: DetectionEvent) {
        guard let context = modelContext else { return }

        switch event {
        case .visitStarted(let anchor, let arrivalDate):
            // 1. Asignar lugar mediante PlaceMatcher
            let matchedPlace = PlaceMatcher.findBestMatchingPlace(for: anchor, in: self.places)

            // 2. Crear nueva visita en SwiftData
            let newVisit = Visit(
                id: UUID(),
                placeId: matchedPlace?.id,
                place: matchedPlace,
                latitude: anchor.latitude,
                longitude: anchor.longitude,
                arrivalDate: arrivalDate,
                departureDate: nil,
                deviceSource: .watch,
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
            syncWithIphone()

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
            syncWithIphone()

        case .readingFiltered(let reason, _):
            print("[WatchTracking] Lectura GPS filtrada: \(reason)")
        }
    }

    /// Carga lugares y visitas desde SwiftData local
    public func loadLocalData() {
        guard let context = modelContext else { return }

        do {
            let placeDescriptor = FetchDescriptor<Place>(sortBy: [SortDescriptor(\.name)])
            self.places = try context.fetch(placeDescriptor)

            let visitDescriptor = FetchDescriptor<Visit>(sortBy: [SortDescriptor(\.arrivalDate, order: .reverse)])
            self.recentVisits = try context.fetch(visitDescriptor)

            // Buscar si hay una visita activa en curso
            self.activeVisit = recentVisits.first { $0.isOngoing }
            if let active = activeVisit {
                self.currentPlace = active.place
                self.trackingStatusText = currentPlace != nil ? "En \(currentPlace!.name)" : "Estancia activa"
            }
        } catch {
            print("[WatchTracking] Error al cargar datos locales: \(error)")
        }
    }

    /// Sincroniza el estado del reloj con el iPhone mediante WatchConnectivity
    public func syncWithIphone() {
        #if canImport(WatchConnectivity)
        isSyncing = true
        let placesDTO = places.map { PlaceDTO(from: $0) }
        let visitsDTO = recentVisits.map { VisitDTO(from: $0) }

        let payload = SyncPayload(
            places: placesDTO,
            visits: visitsDTO,
            source: .watch,
            sentAt: Date()
        )

        WatchConnectivityManager.shared.sendPayload(payload)
        self.lastSyncMessage = "Sincronizado: \(Date().formatted(date: .omitted, time: .shortened))"
        isSyncing = false
        #endif
    }

    /// Aplica un payload entrante del iPhone (upsert de lugares y reconciliación de estancias)
    public func applyIncomingPayload(_ payload: SyncPayload) {
        guard let context = modelContext else { return }

        // 1. Reconciliar Lugares (LWW)
        let localPlacesDTO = places.map { PlaceDTO(from: $0) }
        let reconciledPlacesDTO = PlaceReconciler.reconcile(existing: localPlacesDTO, incoming: payload.places)

        for pDTO in reconciledPlacesDTO {
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

        // 2. Reconciliar Visitas aplicando precedencia del Watch
        let localWatchVisits = recentVisits.filter { $0.deviceSource == .watch }.map { VisitDTO(from: $0) }
        let incomingIphoneVisits = payload.visits.filter { $0.deviceSource == .iphone }

        let reconciledVisitsDTO = VisitReconciler.reconcile(
            iphoneVisits: incomingIphoneVisits,
            watchVisits: localWatchVisits
        )

        for vDTO in reconciledVisitsDTO {
            if let existing = recentVisits.first(where: { $0.id == vDTO.id }) {
                existing.arrivalDate = vDTO.arrivalDate
                existing.departureDate = vDTO.departureDate
                existing.isMovingDetected = vDTO.isMovingDetected
                existing.updatedAt = vDTO.updatedAt
            } else {
                let matchedPlace = vDTO.placeId.flatMap { pid in places.first { $0.id == pid } }
                let newVisit = Visit(
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
                context.insert(newVisit)
            }
        }

        try? context.save()
        loadLocalData()
        self.lastSyncMessage = "Recibido de iPhone: \(Date().formatted(date: .omitted, time: .shortened))"
    }

    private func startActiveTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
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
