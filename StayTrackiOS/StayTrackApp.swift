import SwiftUI
import SwiftData
import StayTrackCore

@main
struct StayTrackApp: App {
    var sharedModelContainer: ModelContainer = {
        do {
            return try SwiftDataStack.createPersistentContainer()
        } catch {
            fatalError("No se pudo inicializar ModelContainer en iOS: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            iOSContentView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}
