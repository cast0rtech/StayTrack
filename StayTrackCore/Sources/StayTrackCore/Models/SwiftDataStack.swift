import Foundation
import SwiftData

/// Fábrica y gestor centralizado del contenedor SwiftData.
/// Asegura que tanto iOS como watchOS utilicen la misma configuración de esquema
/// y opciones de persistencia sin duplicación de código.
public struct SwiftDataStack {
    /// Esquema oficial que agrupa Place y Visit
    public static var schema: Schema {
        Schema([
            Place.self,
            Visit.self
        ])
    }

    /// Crea un contenedor en memoria, ideal para pruebas unitarias y SwiftUI Previews
    @MainActor
    public static func createInMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Crea un contenedor persistente en disco
    @MainActor
    public static func createPersistentContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
