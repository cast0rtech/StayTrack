import SwiftUI
import SwiftData
import StayTrackCore

/// Punto de entrada principal para StayTrack iOS.
///
/// Arquitectura:
/// - Persiste localmente mediante SwiftData con el esquema unificado de StayTrackCore.
/// - Sincroniza bidireccionalmente con StayTrack Watch mediante WatchConnectivity.
/// - Implementa detección de respaldo con CoreLocation cuando el Apple Watch no está disponible.
@main
struct StayTrackApp: App {
    let container: ModelContainer

    init() {
        do {
            self.container = try SwiftDataStack.createPersistentContainer()
        } catch {
            fatalError("Error crítico al inicializar SwiftData ModelContainer en iOS: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            iOSContentView()
                .modelContainer(container)
        }
    }
}
