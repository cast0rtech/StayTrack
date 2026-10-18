import Testing
import Foundation
@testable import StayTrackCore

struct StayTrackCoreTests {

    // MARK: - 1. TESTS DE DETECCIÓN DE ESTANCIA

    /// Parada válida: permanencia superior a 2 minutos dentro del radio R -> inicia estancia
    @Test func testDeteccionParadaValida() async throws {
        let detector = AnchorZoneDetector(
            configuration: AnchorZoneDetector.Configuration(
                detectionRadius: 75.0,
                minStayDuration: 120.0,
                maxAccuracyThreshold: 50.0
            )
        )

        let anchor = Coordinate(latitude: 40.416775, longitude: -3.703790)
        let startTime = Date(timeIntervalSince1970: 1700000000)

        // Lectura 1: t = 0s
        let event0 = detector.process(
            sample: LocationSample(coordinate: anchor, horizontalAccuracy: 10.0, timestamp: startTime)
        )
        #expect(event0 == nil) // Aún en evaluación de candidato

        // Lectura 2: t = 60s (dentro del radio, pero < 2 min)
        let event60 = detector.process(
            sample: LocationSample(coordinate: anchor, horizontalAccuracy: 12.0, timestamp: startTime.addingTimeInterval(60))
        )
        #expect(event60 == nil)

        // Lectura 3: t = 125s (> 120s dentro del radio de 75m)
        let event125 = detector.process(
            sample: LocationSample(coordinate: anchor, horizontalAccuracy: 8.0, timestamp: startTime.addingTimeInterval(125))
        )
        #expect(event125 != nil)

        if case .visitStarted(let confirmedAnchor, let arrivalDate, _) = event125 {
            #expect(confirmedAnchor == anchor)
            #expect(arrivalDate == startTime)
        } else {
            Issue.record("Se esperaba evento visitStarted")
        }
    }

    /// Salida real: permanencia fuera del radio de forma sostenida -> cierra estancia
    @Test func testDeteccionSalidaReal() async throws {
        let detector = AnchorZoneDetector(
            configuration: AnchorZoneDetector.Configuration(
                detectionRadius: 75.0,
                minStayDuration: 120.0,
                sustainedExitDuration: 60.0,
                consecutiveExitThreshold: 3
            )
        )

        let anchor = Coordinate(latitude: 40.4168, longitude: -3.7038)
        let startTime = Date(timeIntervalSince1970: 1700000000)

        // Confirmar estancia activa
        detector.process(sample: LocationSample(coordinate: anchor, horizontalAccuracy: 10.0, timestamp: startTime))
        detector.process(sample: LocationSample(coordinate: anchor, horizontalAccuracy: 10.0, timestamp: startTime.addingTimeInterval(130)))

        #expect(detector.currentState == .activeVisit(anchor: anchor, arrivalDate: startTime))

        // Lectura 1 fuera del radio (a 500 m) en t = 140s
        let outsideCoord = Coordinate(latitude: 40.4220, longitude: -3.7038)
        let exit1 = detector.process(sample: LocationSample(coordinate: outsideCoord, horizontalAccuracy: 10.0, timestamp: startTime.addingTimeInterval(140)))
        #expect(exit1 == nil) // Primera lectura fuera, no confirmada aún

        // Lectura 2 fuera en t = 205s (65 segundos fuera de la zona > sustainedExitDuration = 60s)
        let exit2 = detector.process(sample: LocationSample(coordinate: outsideCoord, horizontalAccuracy: 10.0, timestamp: startTime.addingTimeInterval(205)))
        #expect(exit2 != nil)

        if case .visitEnded(_, let arrival, let departure, _) = exit2 {
            #expect(arrival == startTime)
            #expect(departure == startTime.addingTimeInterval(140)) // Fecha de la primera salida
        } else {
            Issue.record("Se esperaba evento visitEnded")
        }

        #expect(detector.currentState == .idle)
    }

    /// Salida falsa por deriva GPS: una lectura externa transitoria o con mala precisión no debe cerrar la estancia
    @Test func testDeteccionSalidaFalsaDerivaGPS() async throws {
        let detector = AnchorZoneDetector(
            configuration: AnchorZoneDetector.Configuration(
                detectionRadius: 75.0,
                minStayDuration: 120.0,
                maxAccuracyThreshold: 50.0,
                sustainedExitDuration: 60.0,
                consecutiveExitThreshold: 3
            )
        )

        let anchor = Coordinate(latitude: 40.4168, longitude: -3.7038)
        let startTime = Date(timeIntervalSince1970: 1700000000)

        // Iniciar y confirmar estancia
        detector.process(sample: LocationSample(coordinate: anchor, horizontalAccuracy: 10.0, timestamp: startTime))
        detector.process(sample: LocationSample(coordinate: anchor, horizontalAccuracy: 10.0, timestamp: startTime.addingTimeInterval(130)))

        // 1. Salto puntual fuera por rebote/deriva GPS en t = 140s
        let glitchCoord = Coordinate(latitude: 40.4210, longitude: -3.7038)
        let glitchEvent = detector.process(sample: LocationSample(coordinate: glitchCoord, horizontalAccuracy: 15.0, timestamp: startTime.addingTimeInterval(140)))
        #expect(glitchEvent == nil)

        // 2. Inmediatamente en t = 150s la siguiente lectura vuelve al punto ancla (dentro de los 75m)
        let backInsideEvent = detector.process(sample: LocationSample(coordinate: anchor, horizontalAccuracy: 10.0, timestamp: startTime.addingTimeInterval(150)))
        #expect(backInsideEvent == nil)

        // La visita NO se cerró y sigue activa
        #expect(detector.currentState == .activeVisit(anchor: anchor, arrivalDate: startTime))

        // 3. Lectura con mala precisión (> 50 m): se descarta y no afecta a la visita
        let badAccuracyEvent = detector.process(sample: LocationSample(coordinate: glitchCoord, horizontalAccuracy: 75.0, timestamp: startTime.addingTimeInterval(160)))
        #expect(badAccuracyEvent != nil)
        if case .readingFiltered(let reason, let accuracy) = badAccuracyEvent {
            #expect(accuracy == 75.0)
            #expect(reason.contains("> 50.0m"))
        }

        // Continúa activa
        #expect(detector.currentState == .activeVisit(anchor: anchor, arrivalDate: startTime))
    }

    /// Estancia menor de 2 minutos: desplazarse antes de los 120s no crea estancia
    @Test func testDeteccionEstanciaMenor2Minutos() async throws {
        let detector = AnchorZoneDetector(
            configuration: AnchorZoneDetector.Configuration(minStayDuration: 120.0)
        )

        let coordA = Coordinate(latitude: 40.4168, longitude: -3.7038)
        let startTime = Date(timeIntervalSince1970: 1700000000)

        // Lectura en coordA
        detector.process(sample: LocationSample(coordinate: coordA, horizontalAccuracy: 10.0, timestamp: startTime))

        // Siguiente lectura a los 90s pero en coordB (a 400 metros de distancia)
        let coordB = Coordinate(latitude: 40.4200, longitude: -3.7038)
        let moveEvent = detector.process(sample: LocationSample(coordinate: coordB, horizontalAccuracy: 10.0, timestamp: startTime.addingTimeInterval(90)))

        // No se inició ninguna visita formal
        #expect(moveEvent == nil)
        #expect(detector.currentState == .evaluatingCandidate(anchor: coordB, firstSeen: startTime.addingTimeInterval(90)))
    }

    // MARK: - 2. TESTS DE ASIGNACIÓN A LUGARES

    /// Asignación dentro del radio de un favorito: el favorito tiene prioridad sobre el no favorito
    @Test func testAsignacionDentroRadioFavorito() async throws {
        let anchor = Coordinate(latitude: 40.4168, longitude: -3.7038)

        // Lugar A: no favorito, a 15 metros
        let lugarComun = PlaceDTO(
            id: UUID(),
            name: "Café Cercano",
            isFavorite: false,
            category: .otro,
            latitude: 40.4169,
            longitude: -3.7038,
            radius: 75.0
        )

        // Lugar B: favorito, a 30 metros (ambos contienen el punto)
        let lugarFavorito = PlaceDTO(
            id: UUID(),
            name: "Mi Casa",
            isFavorite: true,
            category: .casa,
            latitude: 40.4170,
            longitude: -3.7038,
            radius: 75.0
        )

        var places = [lugarComun, lugarFavorito]
        var visit = VisitDTO(
            id: UUID(),
            anchorCoordinate: anchor,
            accuracy: 10.0
        )

        let asignado = PlaceMatcher.assignPlaceDTO(to: &visit, in: &places)

        #expect(asignado.id == lugarFavorito.id)
        #expect(asignado.name == "Mi Casa")
        #expect(visit.placeId == lugarFavorito.id)
    }

    /// Asignación a lugar nuevo: si no encaja en ningún lugar, crea un Place sin nombre
    @Test func testAsignacionLugarNuevo() async throws {
        let anchor = Coordinate(latitude: 40.5000, longitude: -3.5000)

        // Lista de lugares vacía
        var places: [PlaceDTO] = []
        var visit = VisitDTO(
            id: UUID(),
            anchorCoordinate: anchor,
            accuracy: 10.0
        )

        let asignado = PlaceMatcher.assignPlaceDTO(to: &visit, in: &places, defaultRadius: 75.0)

        #expect(places.count == 1)
        #expect(asignado.name == "") // Place sin nombre
        #expect(asignado.latitude == anchor.latitude)
        #expect(asignado.longitude == anchor.longitude)
        #expect(asignado.radius == 75.0)
        #expect(visit.placeId == asignado.id)
    }

    /// Asignación entre dos lugares cercanos: desempate por favorito y por cercanía
    @Test func testAsignacionDosLugaresCercanos() async throws {
        let anchor = Coordinate(latitude: 40.4168, longitude: -3.7038)

        // Lugar A: a 10 metros de distancia
        let lugarA = PlaceDTO(
            id: UUID(),
            name: "Oficina Torre A",
            isFavorite: true,
            category: .trabajo,
            latitude: 40.41689,
            longitude: -3.7038,
            radius: 75.0
        )

        // Lugar B: a 45 metros de distancia (también favorito)
        let lugarB = PlaceDTO(
            id: UUID(),
            name: "Oficina Torre B",
            isFavorite: true,
            category: .trabajo,
            latitude: 40.4172,
            longitude: -3.7038,
            radius: 75.0
        )

        var places = [lugarB, lugarA]
        var visit = VisitDTO(id: UUID(), anchorCoordinate: anchor)

        // Al ser ambos favoritos, prevalece el más cercano (Lugar A)
        let asignado = PlaceMatcher.assignPlaceDTO(to: &visit, in: &places)
        #expect(asignado.id == lugarA.id)
        #expect(asignado.name == "Oficina Torre A")
    }

    // MARK: - 3. TESTS DE RECONCILIACIÓN

    /// Solapamiento total: el Visit de origen phone queda totalmente absorbido por el reloj -> se descarta
    @Test func testReconciliacionSolapamientoTotal() async throws {
        let baseDate = Date(timeIntervalSince1970: 1700000000)

        // Estancia de iPhone: 10:15 a 10:45
        let phoneVisit = VisitDTO(
            id: UUID(),
            startDate: baseDate.addingTimeInterval(900),
            endDate: baseDate.addingTimeInterval(2700),
            source: .phone,
            anchorCoordinate: Coordinate(latitude: 40.4168, longitude: -3.7038)
        )

        // Estancia de Watch que cubre todo el tramo: 10:00 a 11:00
        let watchVisit = VisitDTO(
            id: UUID(),
            startDate: baseDate,
            endDate: baseDate.addingTimeInterval(3600),
            source: .watch,
            anchorCoordinate: Coordinate(latitude: 40.4168, longitude: -3.7038)
        )

        let reconciliadas = VisitReconciler.reconcile(
            iphoneVisits: [phoneVisit],
            watchVisits: [watchVisit]
        )

        #expect(reconciliadas.count == 1)
        #expect(reconciliadas.first?.id == watchVisit.id)
        #expect(reconciliadas.first?.source == .watch)
    }

    /// Solapamiento con movimiento del reloj (MovementSample): descarta o recorta el phone
    @Test func testReconciliacionConMovementSampleReloj() async throws {
        let baseDate = Date(timeIntervalSince1970: 1700000000)

        // iPhone estaba estático en una visita: 10:00 a 11:00
        let phoneVisit = VisitDTO(
            id: UUID(),
            startDate: baseDate,
            endDate: baseDate.addingTimeInterval(3600),
            source: .phone,
            anchorCoordinate: Coordinate(latitude: 40.4168, longitude: -3.7038)
        )

        // El Watch detectó movimiento de 10:00 a 11:00 (el usuario se movía con el reloj)
        let watchMovement = MovementSampleDTO(
            id: UUID(),
            device: .watch,
            startDate: baseDate,
            endDate: baseDate.addingTimeInterval(3600)
        )

        let reconciliadas = VisitReconciler.reconcile(
            iphoneVisits: [phoneVisit],
            watchVisits: [],
            watchMovements: [watchMovement]
        )

        // La visita del iPhone queda totalmente descartada por solapamiento con movimiento del reloj
        #expect(reconciliadas.isEmpty)
    }

    /// Solapamiento parcial: la estancia de origen phone se recorta en la frontera de actividad del reloj
    @Test func testReconciliacionSolapamientoParcial() async throws {
        let baseDate = Date(timeIntervalSince1970: 1700000000)

        // Estancia de iPhone: 10:00 a 11:30 (90 min)
        let phoneVisit = VisitDTO(
            id: UUID(),
            startDate: baseDate,
            endDate: baseDate.addingTimeInterval(5400),
            source: .phone,
            anchorCoordinate: Coordinate(latitude: 40.4168, longitude: -3.7038)
        )

        // Estancia de Watch: 11:00 a 12:00 (solapa entre 11:00 y 11:30)
        let watchVisit = VisitDTO(
            id: UUID(),
            startDate: baseDate.addingTimeInterval(3600),
            endDate: baseDate.addingTimeInterval(7200),
            source: .watch,
            anchorCoordinate: Coordinate(latitude: 40.4180, longitude: -3.7040)
        )

        let reconciliadas = VisitReconciler.reconcile(
            iphoneVisits: [phoneVisit],
            watchVisits: [watchVisit]
        )

        #expect(reconciliadas.count == 2)
        let trimmedPhone = reconciliadas.first { $0.source == .phone }
        #expect(trimmedPhone != nil)
        #expect(trimmedPhone?.endDate == watchVisit.startDate) // Recortado a las 11:00
        #expect(trimmedPhone?.duration == 3600) // 1 hora resultante
    }

    /// Solapamiento nulo: no existe solapamiento temporal, ambas estancias coexisten
    @Test func testReconciliacionSolapamientoNulo() async throws {
        let baseDate = Date(timeIntervalSince1970: 1700000000)

        // iPhone: 09:00 a 10:00
        let phoneVisit = VisitDTO(
            id: UUID(),
            startDate: baseDate,
            endDate: baseDate.addingTimeInterval(3600),
            source: .phone,
            anchorCoordinate: Coordinate(latitude: 40.4168, longitude: -3.7038)
        )

        // Watch: 11:00 a 12:00 (sin solapamiento)
        let watchVisit = VisitDTO(
            id: UUID(),
            startDate: baseDate.addingTimeInterval(7200),
            endDate: baseDate.addingTimeInterval(10800),
            source: .watch,
            anchorCoordinate: Coordinate(latitude: 40.4180, longitude: -3.7040)
        )

        let reconciliadas = VisitReconciler.reconcile(
            iphoneVisits: [phoneVisit],
            watchVisits: [watchVisit]
        )

        #expect(reconciliadas.count == 2)
        #expect(reconciliadas[0].id == phoneVisit.id)
        #expect(reconciliadas[1].id == watchVisit.id)
    }

    // MARK: - 4. TESTS DE GESTIÓN DE FAVORITOS Y FUSIÓN DE HISTÓRICO

    @Test func testGestionFavoritosYFusionHistorico() async throws {
        let coordCasa = Coordinate(latitude: 40.4168, longitude: -3.7038)
        var places: [PlaceDTO] = []
        var visits: [VisitDTO] = []

        // 1. Crear favorito desde ubicación
        let casa = PlaceManager.createFavoriteFromLocationDTO(
            coordenada: coordCasa,
            nombre: "Mi Casa",
            categoria: .casa,
            places: &places
        )
        #expect(casa.isFavorite == true)
        #expect(places.count == 1)

        // 2. Crear una estancia asignada a un lugar temporal
        let lugarTemp = PlaceDTO(
            id: UUID(),
            name: "Lugar Temporal",
            isFavorite: false,
            latitude: 40.4169,
            longitude: -3.7038
        )
        places.append(lugarTemp)

        let visita = VisitDTO(
            id: UUID(),
            placeId: lugarTemp.id,
            startDate: Date().addingTimeInterval(-3600),
            endDate: Date(),
            anchorCoordinate: coordCasa
        )
        visits.append(visita)

        // 3. Renombrar lugar y verificar actualización de histórico
        PlaceManager.renamePlaceDTO(
            placeId: lugarTemp.id,
            nuevoNombre: "Oficina Renombrada",
            places: &places,
            visitas: &visits
        )
        #expect(places.first { $0.id == lugarTemp.id }?.name == "Oficina Renombrada")

        // 4. Fusionar lugar temporal dentro de Mi Casa -> las visitas deben apuntar a Mi Casa
        PlaceManager.mergePlacesDTO(
            sourceId: lugarTemp.id,
            into: casa.id,
            places: &places,
            visitas: &visits
        )
        #expect(places.count == 1) // El lugar temporal fue eliminado
        #expect(visits.first?.placeId == casa.id) // Histórico actualizado con el ID destino
    }

    // MARK: - 5. TESTS DE UTILIDADES, AGREGACIÓN Y EXPORTACIÓN

    @Test func testUtilidadesFormateoYAgregacion() async throws {
        // Formateo de duraciones
        #expect(StayTrackUtils.formatDuration(3665) == "1h 1m")
        #expect(StayTrackUtils.formatDuration(1800) == "30m")
        #expect(StayTrackUtils.formatDurationDetailed(3665) == "1 h 1 min")

        // Agregación de tiempo por lugar y categoría en un rango de fechas
        let baseDate = Date(timeIntervalSince1970: 1700000000)
        let range = DateInterval(start: baseDate, duration: 86400) // 1 día

        let place = Place(nombre: "Gym", latitud: 40.4, longitud: -3.7, categoria: .entrenamiento)
        let visit = Visit(
            id: UUID(),
            placeId: place.id,
            place: place,
            inicio: baseDate.addingTimeInterval(3600),
            fin: baseDate.addingTimeInterval(7200),
            origen: .watch,
            coordenadaAncla: Coordinate(latitude: 40.4, longitude: -3.7)
        )

        let porLugar = StayTrackUtils.aggregateTimeByPlace(visits: [visit], places: [place], in: range)
        #expect(porLugar.count == 1)
        #expect(porLugar.first?.totalSeconds == 3600)
        #expect(porLugar.first?.hours == 1.0)

        let porCategoria = StayTrackUtils.aggregateTimeByCategory(visits: [visit], places: [place], in: range)
        let gymStat = porCategoria.first { $0.category == .entrenamiento }
        #expect(gymStat?.totalSeconds == 3600)

        // Generación de waypoints para exportar a GPX/KML
        let waypoints = StayTrackUtils.generateWaypoints(places: [place], visits: [visit])
        #expect(waypoints.count == 2) // 1 lugar + 1 visita

        let gpx = StayTrackUtils.generateGPXXML(waypoints: waypoints)
        #expect(gpx.contains("<wpt lat=\"40.400000\" lon=\"-3.700000\">"))
        #expect(gpx.contains("<name>Gym</name>"))

        let kml = StayTrackUtils.generateKMLXML(waypoints: waypoints)
        #expect(kml.contains("<Placemark>"))
        #expect(kml.contains("<name>Gym</name>"))
    }

    @Test
    func testExportacionXLSXReal() throws {
        // Crear datos de prueba
        let lugarOficina = PlaceDTO(
            id: UUID(),
            name: "Sede Principal",
            isFavorite: true,
            category: .trabajo,
            latitude: 40.4500,
            longitude: -3.6900,
            radius: 75.0
        )
        let visita1 = VisitDTO(
            id: UUID(),
            placeId: lugarOficina.id,
            startDate: Date().addingTimeInterval(-7200),
            endDate: Date().addingTimeInterval(-1800),
            source: .watch,
            anchorCoordinate: Coordinate(latitude: 40.4500, longitude: -3.6900),
            accuracy: 8.5
        )

        // Generar archivo .xlsx real
        let xlsxData = XLSXExporter.generateXLSXData(visits: [visita1], places: [lugarOficina])

        #expect(!xlsxData.isEmpty)
        #expect(xlsxData.count > 1000)

        // Verificar cabecera mágica ZIP (PK\x03\x04) estándar de OpenXML
        let prefixBytes = Array(xlsxData.prefix(4))
        #expect(prefixBytes == [0x50, 0x4B, 0x03, 0x04])

        // Validar integridad estructural con unzip
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_\(UUID().uuidString).xlsx")
        try xlsxData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-t", tempURL.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        #expect(process.terminationStatus == 0)
    }

    @Test
    @MainActor
    func testSincronizacionUpsertSinDuplicados() throws {
        let container = try SwiftDataStack.createInMemoryContainer()
        let context = container.mainContext

        let placeId = UUID()
        let visitId = UUID()
        let sampleId = UUID()

        // 1. Primera inserción desde el reloj
        let lugarInicial = Place(
            id: placeId,
            nombre: "Oficina Antigua",
            latitud: 40.4168,
            longitud: -3.7038,
            isFavorite: false,
            categoria: .trabajo
        )
        let visitaInicial = Visit(
            id: visitId,
            placeId: placeId,
            inicio: Date().addingTimeInterval(-3600),
            fin: nil,
            origen: .watch,
            coordenadaAncla: Coordinate(latitude: 40.4168, longitude: -3.7038)
        )
        let muestraMovimiento = MovementSample(
            id: sampleId,
            dispositivo: .watch,
            inicio: Date().addingTimeInterval(-1800),
            fin: Date().addingTimeInterval(-1200)
        )

        context.insert(lugarInicial)
        context.insert(visitaInicial)
        context.insert(muestraMovimiento)
        try context.save()

        // 2. Simulación de sincronización de actualización (mismo UUID, nuevos valores)
        let placeDTOActualizado = PlaceDTO(
            id: placeId,
            name: "Oficina Central",
            isFavorite: true,
            category: .trabajo,
            latitude: 40.4168,
            longitude: -3.7038
        )
        let visitDTOActualizada = VisitDTO(
            id: visitId,
            placeId: placeId,
            startDate: visitaInicial.inicio,
            endDate: Date(),
            source: .watch,
            anchorCoordinate: Coordinate(latitude: 40.4168, longitude: -3.7038)
        )

        // Ejecutar upsert
        let placeDescriptor = FetchDescriptor<Place>()
        let placesEncontrados = try context.fetch(placeDescriptor)
        if let existingPlace = placesEncontrados.first(where: { $0.id == placeDTOActualizado.id }) {
            existingPlace.nombre = placeDTOActualizado.name
            existingPlace.isFavorite = placeDTOActualizado.isFavorite
        } else {
            context.insert(placeDTOActualizado.toModel())
        }

        let visitDescriptor = FetchDescriptor<Visit>()
        let visitasEncontradas = try context.fetch(visitDescriptor)
        if let existingVisit = visitasEncontradas.first(where: { $0.id == visitDTOActualizada.id }) {
            existingVisit.fin = visitDTOActualizada.endDate
        } else {
            context.insert(visitDTOActualizada.toModel())
        }

        try context.save()

        // 3. Verificación de no duplicados y actualización
        let placesFinales = try context.fetch(FetchDescriptor<Place>())
        let visitasFinales = try context.fetch(FetchDescriptor<Visit>())
        let muestrasFinales = try context.fetch(FetchDescriptor<MovementSample>())

        #expect(placesFinales.count == 1)
        #expect(placesFinales.first?.nombre == "Oficina Central")
        #expect(placesFinales.first?.isFavorite == true)

        #expect(visitasFinales.count == 1)
        #expect(visitasFinales.first?.fin != nil)

        #expect(muestrasFinales.count == 1)
    }

    @Test
    func testExportacionCSVCompleta() {
        let lugar = PlaceDTO(
            id: UUID(),
            name: "Café, \"La Central\"",
            isFavorite: true,
            category: .otro,
            latitude: 40.4168,
            longitude: -3.7038
        )
        let visita = VisitDTO(
            id: UUID(),
            placeId: lugar.id,
            startDate: Date(timeIntervalSince1970: 1700000000),
            endDate: Date(timeIntervalSince1970: 1700003600),
            source: .watch,
            anchorCoordinate: Coordinate(latitude: 40.4168, longitude: -3.7038)
        )

        let csv = CSVExporter.generateCSV(visits: [visita], places: [lugar])

        #expect(csv.contains("Visit_ID,Place_Name,Category,Arrival_ISO"))
        #expect(csv.contains("\"Café, \"\"La Central\"\"\"")) // Escape RFC-4180 de comas y comillas
        #expect(csv.contains("Apple Watch"))
        #expect(csv.contains("60.0")) // 60 minutos
    }

    @Test
    func testExportacionGPXyKMLCompleta() {
        let lugar = PlaceDTO(
            id: UUID(),
            name: "Estación Atocha",
            isFavorite: true,
            category: .otro,
            latitude: 40.4065,
            longitude: -3.6905
        )

        let gpx = GPXExporter.generateGPX(places: [lugar])
        #expect(gpx.contains("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
        #expect(gpx.contains("<gpx version=\"1.1\""))
        #expect(gpx.contains("<wpt lat=\"40.406500\" lon=\"-3.690500\">"))
        #expect(gpx.contains("<name>Estación Atocha</name>"))

        let kml = KMLExporter.generateKML(places: [lugar])
        #expect(kml.contains("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
        #expect(kml.contains("<kml xmlns=\"http://www.opengis.net/kml/2.2\">"))
        #expect(kml.contains("<name>Estación Atocha</name>"))
        #expect(kml.contains("<coordinates>-3.690500,40.406500,0</coordinates>"))
    }
}


