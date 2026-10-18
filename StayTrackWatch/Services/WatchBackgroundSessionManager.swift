import Foundation
import WatchKit

/// Gestor de sesión extendida en segundo plano para watchOS mediante WKExtendedRuntimeSession.
///
/// LIMITACIONES REALES Y RESTRICCIONES DE watchOS:
/// 1. watchOS suspende agresivamente procesos en segundo plano para preservar la reducida batería de muñeca (200-300 mAh).
/// 2. WKExtendedRuntimeSession permite mantener la app activa o despertarla ante eventos de sensores, pero:
///    - `.selfPreservation`: Diseñada para tareas de preservación de estado antes de suspensión.
///    - `.smartAlarm`: Permite monitorización activa de sensores previa a eventos.
///    - No es viable mantener una sesión indefinida 24/7 sin degradar drásticamente la batería (~4-5 horas con GPS permanente).
/// 3. Retrasos de entrega (Coalescing): En segundo plano, watchOS agrupa lecturas satelitales y de sensores para
///    procesarlas en ráfagas espaciadas por varios minutos, lo que puede diferir levemente el instante exacto del check-in.
/// 4. Validación en reloj físico: La gestión de energía del kernel de watchOS, el modo 'Always On' y la transición
///    entre primer y segundo plano solo pueden evaluarse con precisión en hardware real con batería conectada.
@MainActor
public final class WatchBackgroundSessionManager: NSObject, ObservableObject {
    public static let shared = WatchBackgroundSessionManager()

    @Published public private(set) var isSessionRunning: Bool = false
    @Published public private(set) var lastSessionStateDescription: String = "Inactiva"
    @Published public private(set) var lastSessionStartDate: Date?

    private var currentSession: WKExtendedRuntimeSession?

    public override init() {
        super.init()
    }

    /// Inicia una sesión extendida para proteger el procesamiento de check-in y movimiento
    public func startBackgroundSession() {
        guard currentSession == nil || currentSession?.state == .invalid else {
            return
        }

        let session = WKExtendedRuntimeSession()
        session.delegate = self
        self.currentSession = session
        session.start()
        self.lastSessionStateDescription = "Iniciando..."
    }

    /// Detiene la sesión extendida actual
    public func stopBackgroundSession() {
        guard let session = currentSession else { return }
        session.invalidate()
        self.currentSession = nil
        self.isSessionRunning = false
        self.lastSessionStateDescription = "Detenida manualmente"
    }
}

// MARK: - WKExtendedRuntimeSessionDelegate
extension WatchBackgroundSessionManager: @preconcurrency WKExtendedRuntimeSessionDelegate {
    public func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        Task { @MainActor in
            self.isSessionRunning = true
            self.lastSessionStartDate = Date()
            self.lastSessionStateDescription = "Activa (Background habilitado)"
        }
    }

    public func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        Task { @MainActor in
            self.lastSessionStateDescription = "A punto de expirar (Preservando estado)"
        }
    }

    public func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: Error?
    ) {
        Task { @MainActor in
            self.isSessionRunning = false
            self.currentSession = nil
            let reasonStr: String
            switch reason {
            case .none:
                reasonStr = "Completada normalmente"
            case .sessionInProgress:
                reasonStr = "Conflicto con otra sesión"
            case .expired:
                reasonStr = "Tiempo límite de watchOS alcanzado"
            case .suppressedBySystem:
                reasonStr = "Suprimida por el sistema (ahorro de batería)"
            case .resignedFrontmost:
                reasonStr = "La app dejó de estar en primer plano"
            case .error:
                reasonStr = "Error: \(error?.localizedDescription ?? "desconocido")"
            @unknown default:
                reasonStr = "Invalidada con código \(reason.rawValue)"
            }
            self.lastSessionStateDescription = "Inactiva: \(reasonStr)"
        }
    }
}
