import Foundation
#if canImport(CoreMotion) && (os(iOS) || os(watchOS))
import CoreMotion
#endif

/// Gestor de actividad física mediante CoreMotion.
/// Detecta si el usuario/dispositivo está estático o en movimiento.
///
/// Limitación real de simulador:
/// CMMotionActivityManager.isActivityAvailable() SIEMPRE retorna `false` en simuladores de iOS y watchOS.
/// Esta capacidad debe ser validada obligatoriamente en un dispositivo físico.
@MainActor
public final class MotionActivityManager: NSObject, ObservableObject {
    #if canImport(CoreMotion) && (os(iOS) || os(watchOS))
    private let activityManager = CMMotionActivityManager()
    private let motionQueue = OperationQueue()
    #endif

    @Published public private(set) var isMotionAvailable: Bool = false
    @Published public private(set) var isStationary: Bool = true
    @Published public private(set) var isMoving: Bool = false
    @Published public private(set) var currentActivityDescription: String = "Inmóvil"

    public override init() {
        super.init()
        #if canImport(CoreMotion) && (os(iOS) || os(watchOS))
        self.isMotionAvailable = CMMotionActivityManager.isActivityAvailable()
        motionQueue.name = "com.staytrack.motionQueue"
        motionQueue.qualityOfService = .utility
        #else
        self.isMotionAvailable = false
        #endif
    }

    /// Inicia el seguimiento continuo de actividad física
    public func startTrackingActivity(onActivityChange: (@Sendable (Bool) -> Void)? = nil) {
        #if canImport(CoreMotion) && (os(iOS) || os(watchOS))
        guard CMMotionActivityManager.isActivityAvailable() else {
            return
        }

        activityManager.startActivityUpdates(to: motionQueue) { [weak self] activity in
            guard let activity = activity else { return }
            Task { @MainActor in
                let moving = activity.walking || activity.running || activity.automotive || activity.cycling
                let stationary = activity.stationary && !moving

                self?.isStationary = stationary
                self?.isMoving = moving

                if activity.walking {
                    self?.currentActivityDescription = "Caminando"
                } else if activity.running {
                    self?.currentActivityDescription = "Corriendo"
                } else if activity.automotive {
                    self?.currentActivityDescription = "Vehículo"
                } else if activity.cycling {
                    self?.currentActivityDescription = "Bicicleta"
                } else {
                    self?.currentActivityDescription = stationary ? "Inmóvil" : "Desconocido"
                }

                onActivityChange?(moving)
            }
        }
        #endif
    }

    /// Detiene las actualizaciones de actividad física
    public func stopTrackingActivity() {
        #if canImport(CoreMotion) && (os(iOS) || os(watchOS))
        if CMMotionActivityManager.isActivityAvailable() {
            activityManager.stopActivityUpdates()
        }
        #endif
    }
}
