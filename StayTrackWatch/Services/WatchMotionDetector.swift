import Foundation
import CoreMotion
import StayTrackCore

/// Detector de actividad y movimiento corporal en Apple Watch.
///
/// Apoyo a la detección y desambiguación con iPhone:
/// 1. Si el reloj detecta movimiento real del cuerpo (caminar, correr, transporte),
///    registra un MovementSample para invalidar posteriormente en la reconciliación
///    aquellas estancias del iPhone que se hayan solapado temporalmente mientras el teléfono estaba estático.
/// 2. Ahorro de batería: Utiliza CMMotionActivityManager y CMPedometer cuando están disponibles,
///    aprovechando el coprocesador M-series de muy bajo consumo en lugar de muestrear acelerometría continua.
@MainActor
public final class WatchMotionDetector: ObservableObject {
    @Published public private(set) var isMoving: Bool = false
    @Published public private(set) var currentActivityTitle: String = "Estático"
    @Published public private(set) var currentSampleStartDate: Date?

    public var onMovementSampleCompleted: ((MovementSampleDTO) -> Void)?

    private let activityManager = CMMotionActivityManager()
    private let pedometer = CMPedometer()
    private let motionManager = CMMotionManager()

    private var activeMovementStart: Date?
    private let activityQueue = OperationQueue()

    public init() {
        activityQueue.name = "com.staytrack.watch.motion"
        activityQueue.maxConcurrentOperationCount = 1
    }

    /// Inicia la monitorización de movimiento
    public func startMonitoring() {
        if CMMotionActivityManager.isActivityAvailable() {
            startActivityMonitoring()
        } else if CMPedometer.isPedometerEventTrackingAvailable() {
            startPedometerMonitoring()
        } else {
            startAccelerometerFallback()
        }
    }

    /// Detiene la monitorización y cierra cualquier muestra en curso
    public func stopMonitoring() {
        if CMMotionActivityManager.isActivityAvailable() {
            activityManager.stopActivityUpdates()
        }
        if CMPedometer.isPedometerEventTrackingAvailable() {
            pedometer.stopEventUpdates()
        }
        if motionManager.isAccelerometerActive {
            motionManager.stopAccelerometerUpdates()
        }

        closeCurrentMovementSample()
    }

    // MARK: - Estrategias de Detección

    private func startActivityMonitoring() {
        activityManager.startActivityUpdates(to: activityQueue) { [weak self] activity in
            guard let self = self, let activity = activity else { return }

            Task { @MainActor in
                let moving = activity.walking || activity.running || activity.automotive || activity.cycling
                let title: String
                if activity.running {
                    title = "Corriendo"
                } else if activity.walking {
                    title = "Caminando"
                } else if activity.automotive {
                    title = "En transporte"
                } else if activity.cycling {
                    title = "En bicicleta"
                } else if activity.stationary {
                    title = "Estático"
                } else {
                    title = moving ? "En movimiento" : "Quieto"
                }

                self.handleMovementState(isMoving: moving, title: title)
            }
        }
    }

    private func startPedometerMonitoring() {
        pedometer.startEventUpdates { [weak self] event, error in
            guard let self = self, let event = event, error == nil else { return }

            Task { @MainActor in
                let moving = (event.type == .resume)
                let title = moving ? "En movimiento" : "Estático"
                self.handleMovementState(isMoving: moving, title: title)
            }
        }
    }

    private func startAccelerometerFallback() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 1.0 // Baja frecuencia para no drenar batería

        motionManager.startAccelerometerUpdates(to: activityQueue) { [weak self] data, error in
            guard let self = self, let data = data, error == nil else { return }

            // Magnitud del vector de aceleración menos gravedad terrestre (1g)
            let magnitude = sqrt(data.acceleration.x * data.acceleration.x +
                                 data.acceleration.y * data.acceleration.y +
                                 data.acceleration.z * data.acceleration.z)
            let userMotion = abs(magnitude - 1.0)
            let moving = userMotion > 0.15

            Task { @MainActor in
                self.handleMovementState(isMoving: moving, title: moving ? "En movimiento" : "Estático")
            }
        }
    }

    // MARK: - Gestión de Muestras de Movimiento

    private func handleMovementState(isMoving: Bool, title: String) {
        self.isMoving = isMoving
        self.currentActivityTitle = title

        if isMoving {
            if activeMovementStart == nil {
                let now = Date()
                activeMovementStart = now
                currentSampleStartDate = now
            }
        } else {
            closeCurrentMovementSample()
        }
    }

    private func closeCurrentMovementSample() {
        guard let start = activeMovementStart else { return }
        let end = Date()
        activeMovementStart = nil
        currentSampleStartDate = nil

        // Solo persistir si la muestra de movimiento duró al menos 10 segundos
        let duration = end.timeIntervalSince(start)
        guard duration >= 10.0 else { return }

        let sampleDTO = MovementSampleDTO(
            id: UUID(),
            device: .watch,
            startDate: start,
            endDate: end
        )

        self.onMovementSampleCompleted?(sampleDTO)
    }
}
