import Foundation

/// Generador de exportaciones en formato CSV (RFC-4180).
public struct CSVExporter: Sendable {

    /// Genera el contenido CSV a partir de visitas y lugares correspondientes.
    public static func generateCSV(
        visits: [VisitDTO],
        places: [PlaceDTO]
    ) -> String {
        let placesMap = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) })
        let isoFormatter = ISO8601DateFormatter()

        var rows: [String] = []

        // Encabezados
        let headers = [
            "Visit_ID",
            "Place_Name",
            "Category",
            "Arrival_ISO",
            "Departure_ISO",
            "Duration_Seconds",
            "Duration_Minutes",
            "Duration_Formatted",
            "Latitude",
            "Longitude",
            "Device_Source",
            "Movement_Detected",
            "Status"
        ]
        rows.append(headers.map { escapeCSV($0) }.joined(separator: ","))

        for visit in visits {
            let matchedPlace = visit.placeId.flatMap { placesMap[$0] }
            let placeName = matchedPlace?.name ?? "Lugar sin nombre"
            let categoryName = matchedPlace?.category.displayName ?? PlaceCategory.otro.displayName

            let arrivalStr = isoFormatter.string(from: visit.startDate)
            let departureStr = visit.endDate.map { isoFormatter.string(from: $0) } ?? "En curso"
            let durationSeconds = Int(visit.duration)
            let durationMinutes = String(format: "%.1f", visit.duration / 60.0)
            let durationFormatted = formatDuration(visit.duration)

            let row = [
                visit.id.uuidString,
                placeName,
                categoryName,
                arrivalStr,
                departureStr,
                "\(durationSeconds)",
                durationMinutes,
                durationFormatted,
                String(format: "%.6f", visit.latitude),
                String(format: "%.6f", visit.longitude),
                visit.source.displayName,
                "No",
                visit.isOngoing ? "En curso" : "Completada"
            ]
            rows.append(row.map { escapeCSV($0) }.joined(separator: ","))
        }

        return rows.joined(separator: "\r\n")
    }

    /// Genera la representación Data codificada en UTF-8 con BOM opcional para Excel
    public static func generateCSVData(
        visits: [VisitDTO],
        places: [PlaceDTO],
        includeBOM: Bool = true
    ) -> Data {
        let csvString = generateCSV(visits: visits, places: places)
        var data = Data()
        if includeBOM {
            // UTF-8 BOM (\u{FEFF}) para que Microsoft Excel detecte caracteres especiales en español
            data.append(contentsOf: [0xEF, 0xBB, 0xBF])
        }
        data.append(Data(csvString.utf8))
        return data
    }

    private static func escapeCSV(_ text: String) -> String {
        var escaped = text.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") || escaped.contains("\r") {
            escaped = "\"\(escaped)\""
        }
        return escaped
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
