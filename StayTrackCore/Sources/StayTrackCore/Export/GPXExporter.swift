import Foundation

/// Generador de archivos GPX 1.1 (GPS Exchange Format) con los lugares y estancias como waypoints.
public struct GPXExporter: Sendable {

    /// Genera una cadena de texto XML GPX 1.1 válida
    public static func generateGPX(
        places: [PlaceDTO],
        visits: [VisitDTO] = []
    ) -> String {
        let isoFormatter = ISO8601DateFormatter()
        let now = isoFormatter.string(from: Date())

        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="StayTrack"
             xmlns="http://www.topografix.com/GPX/1/1"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
          <metadata>
            <name>StayTrack - Lugares y Puntos de Interés</name>
            <desc>Exportación generada por StayTrack para iOS y watchOS</desc>
            <time>\(now)</time>
          </metadata>

        """

        // Waypoints para Lugares (Places)
        for place in places {
            let nameEscaped = escapeXML(place.name.isEmpty ? "Lugar sin nombre" : place.name)
            let desc = escapeXML("Categoría: \(place.category.displayName) | Radio: \(Int(place.radius))m | Favorito: \(place.isFavorite ? "Sí" : "No")")
            let time = isoFormatter.string(from: place.createdAt)

            xml += """
              <wpt lat="\(String(format: "%.6f", place.latitude))" lon="\(String(format: "%.6f", place.longitude))">
                <name>\(nameEscaped)</name>
                <desc>\(desc)</desc>
                <time>\(time)</time>
                <type>\(place.category.rawValue)</type>
                <sym>\(place.isFavorite ? "Flag, Red" : "Waypoint")</sym>
              </wpt>

            """
        }

        // Waypoints para Visitas registradas
        let placesMap = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) })
        for visit in visits {
            let matchedPlace = visit.placeId.flatMap { placesMap[$0] }
            let name = escapeXML("Estancia en \(matchedPlace?.name ?? "Punto ancla")")
            let desc = escapeXML("Llegada: \(isoFormatter.string(from: visit.arrivalDate)) | Duración: \(Int(visit.duration / 60)) min | Dispositivo: \(visit.deviceSource.displayName)")
            let time = isoFormatter.string(from: visit.arrivalDate)

            xml += """
              <wpt lat="\(String(format: "%.6f", visit.latitude))" lon="\(String(format: "%.6f", visit.longitude))">
                <name>\(name)</name>
                <desc>\(desc)</desc>
                <time>\(time)</time>
                <type>Visit</type>
                <sym>Pin, Blue</sym>
              </wpt>

            """
        }

        xml += "</gpx>"
        return xml
    }

    public static func generateGPXData(
        places: [PlaceDTO],
        visits: [VisitDTO] = []
    ) -> Data {
        return Data(generateGPX(places: places, visits: visits).utf8)
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
