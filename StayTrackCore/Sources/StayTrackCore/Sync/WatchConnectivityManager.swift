#if canImport(WatchConnectivity)
import Foundation
import WatchConnectivity
import Combine

/// Gestor de sincronización bidireccional entre iOS y watchOS mediante WatchConnectivity.
///
/// Decisiones de arquitectura:
/// 1. Priorización de entrega en background: Se utiliza `transferUserInfo` como canal primario
///    porque encola las transferencias a nivel de sistema operativo y las entrega automáticamente
///    incluso si la app compañera no está en primer plano.
/// 2. Baja latencia cuando está activa: Si `session.isReachable` es verdadero, se intenta también
///    `sendMessage` para actualización visual instantánea.
/// 3. Resiliencia: La lógica maneja reintentos y sesiones inactivas/desactivadas en iOS.
@MainActor
public final class WatchConnectivityManager: NSObject, ObservableObject {
    public static let shared = WatchConnectivityManager()

    @Published public private(set) var isSupported: Bool = false
    @Published public private(set) var isReachable: Bool = false
    @Published public private(set) var isPaired: Bool = false
    @Published public private(set) var isWatchAppInstalled: Bool = false
    @Published public private(set) var activationState: WCSessionActivationState = .notActivated
    @Published public private(set) var lastReceivedPayload: SyncPayload?
    @Published public private(set) var lastSyncDate: Date?

    public var onPayloadReceived: ((SyncPayload) -> Void)?

    private var session: WCSession?

    public override init() {
        super.init()
        if WCSession.isSupported() {
            self.isSupported = true
            let defaultSession = WCSession.default
            self.session = defaultSession
            defaultSession.delegate = self
            defaultSession.activate()
        }
    }

    /// Envía un SyncPayload a la contraparte (iPhone <-> Watch)
    public func sendPayload(_ payload: SyncPayload) {
        guard let session = session, session.activationState == .activated else {
            print("[WatchConnectivityManager] La sesión no está activada para enviar datos.")
            return
        }

        do {
            let dict = try payload.toUserInfoDictionary()

            // 1. Encolar en background garantizado
            session.transferUserInfo(dict)

            // 2. Si hay conexión en vivo, intentar entrega instantánea
            if session.isReachable {
                session.sendMessage(dict, replyHandler: nil) { error in
                    print("[WatchConnectivityManager] Fallo secundario en sendMessage en vivo: \(error.localizedDescription)")
                }
            }

            self.lastSyncDate = Date()
        } catch {
            print("[WatchConnectivityManager] Error al codificar payload: \(error.localizedDescription)")
        }
    }

    private func handleIncomingDictionary(_ dict: [String: Any]) {
        do {
            if let payload = try SyncPayload.fromUserInfoDictionary(dict) {
                Task { @MainActor in
                    self.lastReceivedPayload = payload
                    self.lastSyncDate = Date()
                    self.onPayloadReceived?(payload)
                }
            }
        } catch {
            print("[WatchConnectivityManager] Error al deserializar payload entrante: \(error.localizedDescription)")
        }
    }
}

extension WatchConnectivityManager: @preconcurrency WCSessionDelegate {
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        self.activationState = activationState
        self.isReachable = session.isReachable
        #if os(iOS)
        self.isPaired = session.isPaired
        self.isWatchAppInstalled = session.isWatchAppInstalled
        #endif
    }

    public func sessionReachabilityDidChange(_ session: WCSession) {
        self.isReachable = session.isReachable
    }

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        self.handleIncomingDictionary(userInfo)
    }

    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        self.handleIncomingDictionary(message)
    }

    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {
    }

    public func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    public func sessionWatchStateDidChange(_ session: WCSession) {
        self.isPaired = session.isPaired
        self.isWatchAppInstalled = session.isWatchAppInstalled
    }
    #endif
}
#endif
