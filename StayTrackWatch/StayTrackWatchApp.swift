import SwiftUI
import SwiftData
import StayTrackCore

/// Punto de entrada principal para StayTrack Watch.
///
/// La aplicación está diseñada para funcionar de forma 100% autónoma en watchOS:
/// - Persiste localmente mediante SwiftData con el esquema unificado de StayTrackCore.
/// - Sigue registrando estancias y movimientos aunque el iPhone esté apagado, fuera de rango o desemparejado.
/// - Sincroniza automáticamente en background vía WatchConnectivity tan pronto como hay conectividad.
@main
struct StayTrackWatchApp: App {
    let container: ModelContainer

    init() {
        do {
            self.container = try SwiftDataStack.createModelContainer()
        } catch {
            fatalError("Error al inicializar SwiftData ModelContainer en Apple Watch: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .modelContainer(container)
        }
    }
}
