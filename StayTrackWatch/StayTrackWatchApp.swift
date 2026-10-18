import SwiftUI
import SwiftData
import StayTrackCore

@main
struct StayTrackWatchApp: App {
    var sharedModelContainer: ModelContainer = {
        do {
            return try SwiftDataStack.createPersistentContainer()
        } catch {
            fatalError("No se pudo inicializar ModelContainer en watchOS: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}
