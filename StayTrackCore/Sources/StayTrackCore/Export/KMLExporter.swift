import Foundation

/// Generador de archivos KML 2.2 (Keyhole Markup Language) para visualización
/// en Google Earth, Apple Maps u otros visores SIG.
public struct KMLExporter: Sendable {

    /// Genera una cadena XML KML 2.2 válida con los lugares marcados
    public static func generateKML(
        places: [PlaceDTO],
        visits: [VisitDTO] = []
    ) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <kml xmlns="http://www.opengis.net/kml/2.2">
          <Document>
            <name>StayTrack - Lugares y Estancias</name>
            <description>Exportación de lugares frecuentes y visitas registradas</description>

        """

        for place in places {
            let name = escapeXML(place.name.isEmpty ? "Lugar sin nombre" : place.name)
            let desc = escapeXML("Categoría: \(place.category.displayName)<br>Radio: \(Int(place.radius))m<br>Favorito: \(place.isFavorite ? "Sí" : "No")")

            xml += """
                <Placemark>
                  <name>\(name)</name>
                  <description>\(desc)</description>
                  <Point>
                    <coordinates>\(String(format: "%.6f", place.longitude)),\(String(format: "%.6f", place.latitude)),0</coordinates>
                  </Point>
                </Placemark>

            """
        }

        let placesMap = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) })
        let isoFormatter = ISO8601DateFormatter()

        for visit in visits {
            let matchedPlace = visit.placeId.flatMap { placesMap[$0] }
            let name = escapeXML("Visita: \(matchedPlace?.name ?? "Punto ancla")")
            let desc = escapeXML("Fecha: \(isoFormatter.string(from: visit.arrivalDate))<br>Duración: \(Int(visit.duration / 60)) min<br>Dispositivo: \(visit.deviceSource.displayName)")

            xml += """
                <Placemark>
                  <name>\(name)</name>
                  <description>\(desc)</description>
                  <Point>
                    <coordinates>\(String(format: "%.6f", visit.longitude)),\(String(format: "%.6f", visit.latitude)),0</coordinates>
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

    public static func generateKMLData(
        places: [PlaceDTO],
        visits: [VisitDTO] = []
    ) -> Data {
        return Data(generateKML(places: places, visits: visits).utf8)
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
