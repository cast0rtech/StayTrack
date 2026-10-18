import Foundation

/// Formatos de exportación admitidos por StayTrack.
public enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case csv
    case xlsx
    case gpx
    case kml
    case mapImage

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .csv:
            return "CSV (.csv)"
        case .xlsx:
            return "Excel (.xlsx)"
        case .gpx:
            return "GPS Exchange Format (.gpx)"
        case .kml:
            return "Google Earth (.kml)"
        case .mapImage:
            return "Mapa con Lugares (.png)"
        }
    }

    public var fileExtension: String {
        switch self {
        case .csv:
            return "csv"
        case .xlsx:
            return "xlsx"
        case .gpx:
            return "gpx"
        case .kml:
            return "kml"
        case .mapImage:
            return "png"
        }
    }

    public var mimeType: String {
        switch self {
        case .csv:
            return "text/csv"
        case .xlsx:
            return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case .gpx:
            return "application/gpx+xml"
        case .kml:
            return "application/vnd.google-earth.kml+xml"
        case .mapImage:
            return "image/png"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .csv:
            return "tablecells"
        case .xlsx:
            return "chart.bar.doc.horizontal"
        case .gpx:
            return "location.north.circle"
        case .kml:
            return "globe.europe.africa.fill"
        case .mapImage:
            return "map.fill"
        }
    }
}
