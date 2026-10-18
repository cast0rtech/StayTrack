import Testing
import Foundation
import CoreLocation
@testable import StayTrackCore

struct StayTrackCoreTests {

    // MARK: - 1. Pruebas de Reconciliación: Solapamiento Nulo

    @Test func testZeroOverlapCoexistence() async throws {
        let baseDate = Date(timeIntervalSince1970: 1700000000)

        // Visita del iPhone: 10:00 a 11:00
        let iphoneVisit = VisitDTO(
            id: UUID(),
            latitude: 40.4168,
            longitude: -3.7038,
            arrivalDate: baseDate,
            departureDate: baseDate.addingTimeInterval(3600),
            deviceSource: .iphone
        )

        // Visita del Watch: 11:30 a 12:30 (sin solapamiento)
        let watchVisit = VisitDTO(
            id: UUID(),
            latitude: 40.4180,
            longitude: -3.7040,
            arrivalDate: baseDate.addingTimeInterval(5400),
            departureDate: baseDate.addingTimeInterval(9000),
            deviceSource: .watch
        )

        let result = VisitReconciler.reconcile(
            iphoneVisits: [iphoneVisit],
            watchVisits: [watchVisit]
        )

        #expect(result.count == 2)
        #expect(result.first?.id == iphoneVisit.id)
        #expect(result.last?.id == watchVisit.id)
    }

    // MARK: - 2. Pruebas de Reconciliación: Solapamiento Total

    @Test func testTotalOverlapWatchPrecedence() async throws {
        let baseDate = Date(timeIntervalSince1970: 1700000000)

        // Visita del iPhone: 10:15 a 10:45 (30 min)
        let iphoneVisit = VisitDTO(
            id: UUID(),
            latitude: 40.4168,
            longitude: -3.7038,
            arrivalDate: baseDate.addingTimeInterval(900),
            departureDate: baseDate.addingTimeInterval(2700),
            deviceSource: .iphone
        )

        // Visita del Watch que cubre totalmente al iPhone: 10:00 a 11:00 (60 min)
        let watchVisit = VisitDTO(
            id: UUID(),
            latitude: 40.4168,
            longitude: -3.7038,
            arrivalDate: baseDate,
            departureDate: baseDate.addingTimeInterval(3600),
            deviceSource: .watch
        )

        let result = VisitReconciler.reconcile(
            iphoneVisits: [iphoneVisit],
            watchVisits: [watchVisit]
        )

        // El iPhone queda totalmente descartado por la precedencia del Watch
        #expect(result.count == 1)
        #expect(result.first?.id == watchVisit.id)
        #expect(result.first?.deviceSource == .watch)
    }

    @Test func testTotalOverlapInverseSplitting() async throws {
        let baseDate = Date(timeIntervalSince1970: 1700000000)

        // Visita larga de iPhone: 10:00 a 14:00 (4 horas)
        let iphoneVisit = VisitDTO(
            id: UUID(),
            latitude: 40.4168,
            longitude: -3.7038,
            arrivalDate: baseDate,
            departureDate: baseDate.addingTimeInterval(14400),
            deviceSource: .iphone
        )

        // Visita del Watch en medio: 11:00 a 12:00 (1 hora)
        let watchVisit = VisitDTO(
            id: UUID(),
            latitude: 40.4500,
            longitude: -3.6900,
            arrivalDate: baseDate.addingTimeInterval(3600),
            departureDate: baseDate.addingTimeInterval(7200),
            deviceSource: .watch
        )

        let result = VisitReconciler.reconcile(
            iphoneVisits: [iphoneVisit],
            watchVisits: [watchVisit]
        )

        // Debe contener:
        // 1. Segmento iPhone pre (10:00 a 11:00)
        // 2. Visita Watch (11:00 a 12:00)
        // 3. Segmento iPhone post (12:00 a 14:00)
        #expect(result.count == 3)
        #expect(result[0].deviceSource == .iphone)
        #expect(result[0].departureDate == watchVisit.arrivalDate)

        #expect(result[1].id == watchVisit.id)
        #expect(result[1].deviceSource == .watch)

        #expect(result[2].deviceSource == .iphone)
        #expect(result[2].arrivalDate == watchVisit.departureDate)
    }

    // MARK: - 3. Pruebas de Reconciliación: Solapamiento Parcial

    @Test func testPartialOverlapTailTrim() async throws {
        let baseDate = Date(timeIntervalSince1970: 1700000000)

        // iPhone: 10:00 a 11:30
        let iphoneVisit = VisitDTO(
            id: UUID(),
            latitude: 40.4168,
            longitude: -3.7038,
            arrivalDate: baseDate,
            departureDate: baseDate.addingTimeInterval(5400),
            deviceSource: .iphone
        )

        // Watch: 11:00 a 12:00 (solapa la cola del iPhone entre 11:00 y 11:30)
        let watchVisit = VisitDTO(
            id: UUID(),
            latitude: 40.4180,
            longitude: -3.7040,
            arrivalDate: baseDate.addingTimeInterval(3600),
            departureDate: baseDate.addingTimeInterval(7200),
            deviceSource: .watch
        )

        let result = VisitReconciler.reconcile(
            iphoneVisits: [iphoneVisit],
            watchVisits: [watchVisit]
        )

        #expect(result.count == 2)
        // El iPhone debe quedar recortado en su salida a las 11:00 (llegada del Watch)
        let trimmedIphone = result.first { $0.deviceSource == .iphone }
        #expect(trimmedIphone != nil)
        #expect(trimmedIphone?.departureDate == watchVisit.arrivalDate)
        #expect(trimmedIphone?.duration == 3600)
    }

    @Test func testPartialOverlapHeadTrim() async throws {
        let baseDate = Date(timeIntervalSince1970: 1700000000)

        // Watch: 10:00 a 11:00
        let watchVisit = VisitDTO(
            id: UUID(),
            latitude: 40.4180,
            longitude: -3.7040,
            arrivalDate: baseDate,
            departureDate: baseDate.addingTimeInterval(3600),
            deviceSource: .watch
        )

        // iPhone: 10:30 a 12:00 (solapa la cabeza con el Watch entre 10:30 y 11:00)
        let iphoneVisit = VisitDTO(
            id: UUID(),
            latitude: 40.4168,
            longitude: -3.7038,
            arrivalDate: baseDate.addingTimeInterval(1800),
            departureDate: baseDate.addingTimeInterval(7200),
            deviceSource: .iphone
        )

        let result = VisitReconciler.reconcile(
            iphoneVisits: [iphoneVisit],
            watchVisits: [watchVisit]
        )

        #expect(result.count == 2)
        // El iPhone debe quedar recortado en su llegada a las 11:00 (salida del Watch)
        let trimmedIphone = result.first { $0.deviceSource == .iphone }
        #expect(trimmedIphone != nil)
        #expect(trimmedIphone?.arrivalDate == watchVisit.departureDate)
        #expect(trimmedIphone?.departureDate == baseDate.addingTimeInterval(7200))
    }

    @Test func testStationaryIphoneVsMovingWatchConflict() async throws {
        let baseDate = Date(timeIntervalSince1970: 1700000000)

        // iPhone quedó olvidado en el escritorio (isMovingDetected == false) de 10:00 a 12:00
        let iphoneStationaryVisit = VisitDTO(
            id: UUID(),
            latitude: 40.4168,
            longitude: -3.7038,
            arrivalDate: baseDate,
            departureDate: baseDate.addingTimeInterval(7200),
            deviceSource: .iphone,
            isMovingDetected: false
        )

        // Apple Watch estuvo en movimiento y registró estancia en un parque de 10:30 a 11:30 (isMovingDetected == true)
        let watchMovingVisit = VisitDTO(
            id: UUID(),
            latitude: 40.4200,
            longitude: -3.7100,
            arrivalDate: baseDate.addingTimeInterval(1800),
            departureDate: baseDate.addingTimeInterval(5400),
            deviceSource: .watch,
            isMovingDetected: true
        )

        let result = VisitReconciler.reconcile(
            iphoneVisits: [iphoneStationaryVisit],
            watchVisits: [watchMovingVisit]
        )

        // El dispositivo en movimiento (Watch) prevalece sobre el estático.
        // El Visit del iPhone se recorta en el tramo solapado (dividiéndose en pre y post si ambos duran >= 2 min)
        #expect(result.count == 3)
        #expect(result[1].id == watchMovingVisit.id)
        #expect(result[1].deviceSource == .watch)
        #expect(result[0].departureDate == watchMovingVisit.arrivalDate)
        #expect(result[2].arrivalDate == watchMovingVisit.departureDate)
    }

    // MARK: - 4. Pruebas de Detección de Zonas Ancla

    @Test func testAnchorZoneStayThreshold() async throws {
        let detector = AnchorZoneDetector(
            configuration: AnchorZoneDetector.Configuration(
                detectionRadius: 75.0,
                minStayDuration: 120.0,
                maxAccuracyThreshold: 50.0
            )
        )

        let anchor = CLLocationCoordinate2D(latitude: 40.416775, longitude: -3.703790)
        let startTime = Date(timeIntervalSince1970: 1700000000)

        // Lectura 1: t=0 s
        let event1 = detector.process(
            reading: LocationReading(coordinate: anchor, horizontalAccuracy: 10.0, timestamp: startTime)
        )
        #expect(event1 == nil) // Aún en evaluación de candidato

        // Lectura 2: t=60 s dentro del radio (menos de 2 min)
        let event2 = detector.process(
            reading: LocationReading(coordinate: anchor, horizontalAccuracy: 12.0, timestamp: startTime.addingTimeInterval(60))
        )
        #expect(event2 == nil)

        // Lectura 3: t=125 s (> 120 s dentro del radio)
        let event3 = detector.process(
            reading: LocationReading(coordinate: anchor, horizontalAccuracy: 8.0, timestamp: startTime.addingTimeInterval(125))
        )
        #expect(event3 != nil)
        if case .visitStarted(let confirmedAnchor, let arrivalDate) = event3 {
            #expect(confirmedAnchor.latitude == anchor.latitude)
            #expect(arrivalDate == startTime)
        } else {
            Issue.record("Se esperaba evento visitStarted")
        }
    }

    @Test func testAnchorZoneAccuracyFiltering() async throws {
        let detector = AnchorZoneDetector(
            configuration: AnchorZoneDetector.Configuration(maxAccuracyThreshold: 50.0)
        )

        let coord = CLLocationCoordinate2D(latitude: 40.4168, longitude: -3.7038)

        // Lectura con mala precisión (> 50m)
        let badAccuracyEvent = detector.process(
            reading: LocationReading(coordinate: coord, horizontalAccuracy: 65.0)
        )
        #expect(badAccuracyEvent != nil)
        if case .readingFiltered(let reason, let accuracy) = badAccuracyEvent {
            #expect(accuracy == 65.0)
            #expect(reason.contains("> 50.0m"))
        } else {
            Issue.record("Se esperaba filtrado por precisión")
        }

        // Lectura con precisión inválida negativa (-1)
        let negativeAccuracyEvent = detector.process(
            reading: LocationReading(coordinate: coord, horizontalAccuracy: -1.0)
        )
        #expect(negativeAccuracyEvent != nil)
    }

    @Test func testAnchorZoneSustainedDeparture() async throws {
        let detector = AnchorZoneDetector(
            configuration: AnchorZoneDetector.Configuration(
                detectionRadius: 75.0,
                minStayDuration: 120.0,
                sustainedExitDuration: 60.0,
                consecutiveExitThreshold: 3
            )
        )

        let anchor = CLLocationCoordinate2D(latitude: 40.4168, longitude: -3.7038)
        let startTime = Date(timeIntervalSince1970: 1700000000)

        // Iniciar visita válida
        detector.process(reading: LocationReading(coordinate: anchor, horizontalAccuracy: 10.0, timestamp: startTime))
        detector.process(reading: LocationReading(coordinate: anchor, horizontalAccuracy: 10.0, timestamp: startTime.addingTimeInterval(130)))

        // Lectura 1 fuera del radio (a 500m de distancia)
        let outsideCoord = CLLocationCoordinate2D(latitude: 40.4220, longitude: -3.7038)
        let exit1 = detector.process(reading: LocationReading(coordinate: outsideCoord, horizontalAccuracy: 10.0, timestamp: startTime.addingTimeInterval(140)))
        #expect(exit1 == nil) // Primera lectura fuera, no es salida sostenida aún

        // Lectura 2 fuera tras 70 segundos (> sustainedExitDuration = 60s)
        let exit2 = detector.process(reading: LocationReading(coordinate: outsideCoord, horizontalAccuracy: 10.0, timestamp: startTime.addingTimeInterval(215)))
        #expect(exit2 != nil)
        if case .visitEnded(_, _, let departureDate) = exit2 {
            #expect(departureDate == startTime.addingTimeInterval(140))
        } else {
            Issue.record("Se esperaba evento visitEnded")
        }
    }

    // MARK: - 5. Prioridad de Lugares Favoritos

    @Test func testPlaceMatcherFavoritePriority() async throws {
        let center = CLLocationCoordinate2D(latitude: 40.4168, longitude: -3.7038)

        // Lugar no favorito (más cercano: a 10 metros)
        let regularPlace = PlaceDTO(
            id: UUID(),
            name: "Lugar Cercano",
            isFavorite: false,
            category: .other,
            latitude: 40.41685,
            longitude: -3.7038,
            radius: 75.0
        )

        // Lugar favorito (a 40 metros, dentro de radio 75m)
        let favoritePlace = PlaceDTO(
            id: UUID(),
            name: "Mi Casa",
            isFavorite: true,
            category: .home,
            latitude: 40.4171,
            longitude: -3.7038,
            radius: 75.0
        )

        let best = PlaceMatcher.findBestMatchingPlaceDTO(for: center, in: [regularPlace, favoritePlace])

        // La regla de dominio establece que los favoritos tienen prioridad sobre lugares genéricos
        #expect(best?.id == favoritePlace.id)
        #expect(best?.name == "Mi Casa")
    }

    // MARK: - 6. Pruebas de Motores de Exportación

    @Test func testCSVExportGeneration() async throws {
        let place = PlaceDTO(id: UUID(), name: "Oficina", isFavorite: true, category: .work, latitude: 40.4168, longitude: -3.7038)
        let visit = VisitDTO(id: UUID(), placeId: place.id, latitude: 40.4168, longitude: -3.7038, arrivalDate: Date(), departureDate: Date().addingTimeInterval(3600), deviceSource: .watch)

        let csvString = CSVExporter.generateCSV(visits: [visit], places: [place])
        #expect(csvString.contains("Visit_ID,Place_Name,Category"))
        #expect(csvString.contains("Oficina"))
        #expect(csvString.contains("Trabajo"))
        #expect(csvString.contains("Apple Watch"))

        let data = CSVExporter.generateCSVData(visits: [visit], places: [place])
        // Comprobar presencia del BOM UTF-8 (EF BB BF)
        #expect(data[0] == 0xEF && data[1] == 0xBB && data[2] == 0xBF)
    }

    @Test func testXLSXExportGeneration() async throws {
        let place = PlaceDTO(id: UUID(), name: "Gimnasio", isFavorite: true, category: .workout, latitude: 40.4168, longitude: -3.7038)
        let visit = VisitDTO(id: UUID(), placeId: place.id, latitude: 40.4168, longitude: -3.7038, arrivalDate: Date(), departureDate: Date().addingTimeInterval(5400), deviceSource: .iphone)

        let xlsxData = XLSXExporter.generateXLSXData(visits: [visit], places: [place])
        #expect(xlsxData.count > 1000)

        // Verificar firma ZIP (PK\x03\x04 = 0x50, 0x4B, 0x03, 0x04)
        #expect(xlsxData[0] == 0x50)
        #expect(xlsxData[1] == 0x4B)
        #expect(xlsxData[2] == 0x03)
        #expect(xlsxData[3] == 0x04)
    }

    @Test func testGPXAndKMLExportGeneration() async throws {
        let place = PlaceDTO(id: UUID(), name: "Hospital", isFavorite: false, category: .medical, latitude: 40.4168, longitude: -3.7038)
        let visit = VisitDTO(id: UUID(), placeId: place.id, latitude: 40.4168, longitude: -3.7038, arrivalDate: Date(), departureDate: Date().addingTimeInterval(1800), deviceSource: .watch)

        let gpx = GPXExporter.generateGPX(places: [place], visits: [visit])
        #expect(gpx.contains("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
        #expect(gpx.contains("<gpx version=\"1.1\""))
        #expect(gpx.contains("<name>Hospital</name>"))

        let kml = KMLExporter.generateKML(places: [place], visits: [visit])
        #expect(kml.contains("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
        #expect(kml.contains("<kml xmlns=\"http://www.opengis.net/kml/2.2\">"))
        #expect(kml.contains("<name>Hospital</name>"))
    }
}
