import Foundation

public struct PlaceTimeAggregation: Identifiable, Sendable {
    public var id: UUID
    public let placeName: String
    public let category: PlaceCategory
    public let totalSeconds: TimeInterval
    public var hours: Double { totalSeconds / 3600.0 }
}

public struct CategoryTimeAggregation: Identifiable, Sendable {
    public var id: String { category.rawValue }
    public let category: PlaceCategory
    public let totalSeconds: TimeInterval
    public var hours: Double { totalSeconds / 3600.0 }
}

public struct WaypointExportData: Identifiable, Sendable {
    public var id: UUID
    public let name: String
    public let coordinate: Coordinate
    public let descriptionText: String?
    public let categoryName: String?

    public init(
        id: UUID = UUID(),
        name: String,
        coordinate: Coordinate,
        descriptionText: String? = nil,
        categoryName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.descriptionText = descriptionText
        self.categoryName = categoryName
    }
}

/// Utilidades de StayTrack: formateo, agregación temporal y exportación de waypoints.
public struct StayTrackUtils: Sendable {

    // MARK: - Formateo de Duraciones y Fechas

    /// Formatea una duración en segundos a una representación concisa ("2h 15m" o "45m")
    public static func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// Formatea una duración con texto descriptivo ("2 horas 15 minutos")
    public static func formatDurationDetailed(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60

        if hours > 0 {
            return "\(hours) h \(minutes) min"
        } else {
            return "\(minutes) min"
        }
    }

    /// Formatea una fecha en formato ISO8601 estándar
    public static func formatISO8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }

    /// Formatea un intervalo de horas ("10:30 - 12:00" o "10:30 - En curso")
    public static func formatInterval(start: Date, end: Date?) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short

        let startStr = timeFormatter.string(from: start)
        if let end = end {
            return "\(startStr) - \(timeFormatter.string(from: end))"
        } else {
            return "\(startStr) - En curso"
        }
    }

    // MARK: - Agregación de Tiempo por Lugar y por Categoría para un Rango de Fechas

    /// Agrega el tiempo de permanencia por lugar en un rango de fechas determinado
    public static func aggregateTimeByPlace(
        visits: [Visit],
        places: [Place],
        in range: DateInterval
    ) -> [PlaceTimeAggregation] {
        let placesMap = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) })
        var durationMap = [UUID: (name: String, cat: PlaceCategory, duration: TimeInterval)]()

        for visit in visits {
            let vStart = visit.inicio
            let vEnd = visit.fin ?? Date()

            // Calcular solapamiento con el rango
            let overlapStart = max(vStart, range.start)
            let overlapEnd = min(vEnd, range.end)

            guard overlapStart < overlapEnd else { continue }
            let duration = overlapEnd.timeIntervalSince(overlapStart)

            if let pid = visit.placeId, let place = placesMap[pid] {
                let current = durationMap[pid] ?? (place.nombre.isEmpty ? "Lugar sin nombre" : place.nombre, place.categoria, 0)
                durationMap[pid] = (current.name, current.cat, current.duration + duration)
            } else {
                let unassignedKey = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
                let current = durationMap[unassignedKey] ?? ("Punto Ancla", .otro, 0)
                durationMap[unassignedKey] = (current.name, current.cat, current.duration + duration)
            }
        }

        return durationMap.map {
            PlaceTimeAggregation(id: $0.key, placeName: $0.value.name, category: $0.value.cat, totalSeconds: $0.value.duration)
        }.sorted { $0.totalSeconds > $1.totalSeconds }
    }

    /// Agrega el tiempo de permanencia por categoría en un rango de fechas determinado
    public static func aggregateTimeByCategory(
        visits: [Visit],
        places: [Place],
        in range: DateInterval
    ) -> [CategoryTimeAggregation] {
        let placesMap = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) })
        var categoryMap = [PlaceCategory: TimeInterval]()

        for cat in PlaceCategory.allCases {
            categoryMap[cat] = 0
        }

        for visit in visits {
            let vStart = visit.inicio
            let vEnd = visit.fin ?? Date()

            let overlapStart = max(vStart, range.start)
            let overlapEnd = min(vEnd, range.end)

            guard overlapStart < overlapEnd else { continue }
            let duration = overlapEnd.timeIntervalSince(overlapStart)

            let cat: PlaceCategory
            if let pid = visit.placeId, let place = placesMap[pid] {
                cat = place.categoria
            } else {
                cat = .otro
            }

            categoryMap[cat, default: 0] += duration
        }

        return categoryMap.map {
            CategoryTimeAggregation(category: $0.key, totalSeconds: $0.value)
        }.sorted { $0.totalSeconds > $1.totalSeconds }
    }

    // MARK: - Generación de Datos para Exportar a GPX/KML

    /// Genera la lista de waypoints para exportación a partir de lugares y visitas
    public static func generateWaypoints(
        places: [Place],
        visits: [Visit] = []
    ) -> [WaypointExportData] {
        var result: [WaypointExportData] = []

        // Waypoints de Lugares
        for place in places {
            let name = place.nombre.isEmpty ? "Lugar sin nombre" : place.nombre
            let desc = "Categoría: \(place.categoria.displayName) | Radio: \(Int(place.radio))m | Favorito: \(place.isFavorite ? "Sí" : "No")"
            result.append(
                WaypointExportData(
                    id: place.id,
                    name: name,
                    coordinate: place.coordinate,
                    descriptionText: desc,
                    categoryName: place.categoria.displayName
                )
            )
        }

        // Waypoints de Visitas
        for visit in visits {
            let name = "Estancia (\(formatDuration(visit.duration)))"
            let desc = "Inicio: \(formatISO8601(visit.inicio)) | Origen: \(visit.origen.displayName)"
            result.append(
                WaypointExportData(
                    id: visit.id,
                    name: name,
                    coordinate: visit.coordenadaAncla,
                    descriptionText: desc,
                    categoryName: "Estancia"
                )
            )
        }

        return result
    }

    /// Genera XML de GPX 1.1 válido a partir de waypoints
    public static func generateGPXXML(waypoints: [WaypointExportData]) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="StayTrack"
             xmlns="http://www.topografix.com/GPX/1/1"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
          <metadata>
            <name>StayTrack Waypoints</name>
          </metadata>

        """

        for wpt in waypoints {
            let nameEsc = escapeXML(wpt.name)
            let descEsc = escapeXML(wpt.descriptionText ?? "")
            let catEsc = escapeXML(wpt.categoryName ?? "")

            xml += """
              <wpt lat="\(String(format: "%.6f", wpt.coordinate.latitude))" lon="\(String(format: "%.6f", wpt.coordinate.longitude))">
                <name>\(nameEsc)</name>
                <desc>\(descEsc)</desc>
                <type>\(catEsc)</type>
              </wpt>

            """
        }

        xml += "</gpx>"
        return xml
    }

    /// Genera XML de KML 2.2 válido a partir de waypoints
    public static func generateKMLXML(waypoints: [WaypointExportData]) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <kml xmlns="http://www.opengis.net/kml/2.2">
          <Document>
            <name>StayTrack Waypoints</name>

        """

        for wpt in waypoints {
            let nameEsc = escapeXML(wpt.name)
            let descEsc = escapeXML(wpt.descriptionText ?? "")

            xml += """
                <Placemark>
                  <name>\(nameEsc)</name>
                  <description>\(descEsc)</description>
                  <Point>
                    <coordinates>\(String(format: "%.6f", wpt.coordinate.longitude)),\(String(format: "%.6f", wpt.coordinate.latitude)),0</coordinates>
                  </Point>
                </Placemark>

            """
        }

        xml += """
          </Document>
        </kml>
        """
        return xml
    }

    private static func escapeXML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
