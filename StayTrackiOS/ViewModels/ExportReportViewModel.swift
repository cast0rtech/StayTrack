import Foundation
import SwiftUI
import MapKit
import StayTrackCore

/// Rango de fechas predefinido para informes
public enum ReportPresetRange: String, CaseIterable, Identifiable, Sendable {
    case today = "Hoy"
    case thisWeek = "Esta semana"
    case thisMonth = "Este mes"
    case custom = "Personalizado"

    public var id: String { rawValue }

    public func dateInterval(customStart: Date = Date(), customEnd: Date = Date()) -> DateInterval {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .today:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
            return DateInterval(start: start, end: end)

        case .thisWeek:
            guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start else {
                return DateInterval(start: now.addingTimeInterval(-7 * 86400), end: now)
            }
            let end = calendar.date(byAdding: .day, value: 7, to: startOfWeek) ?? now
            return DateInterval(start: startOfWeek, end: end)

        case .thisMonth:
            guard let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start else {
                return DateInterval(start: now.addingTimeInterval(-30 * 86400), end: now)
            }
            let end = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? now
            return DateInterval(start: startOfMonth, end: end)

        case .custom:
            let start = min(customStart, customEnd)
            let end = max(customStart, customEnd)
            return DateInterval(start: start, end: end)
        }
    }
}

/// ViewModel para la generación de informes estadísticos y exportación multiformato.
@MainActor
public final class ExportReportViewModel: ObservableObject {
    @Published public var selectedRange: ReportPresetRange = .thisWeek
    @Published public var customStartDate: Date = Date().addingTimeInterval(-7 * 86400)
    @Published public var customEndDate: Date = Date()

    @Published public var placeAggregations: [PlaceTimeAggregation] = []
    @Published public var categoryAggregations: [CategoryTimeAggregation] = []
    @Published public var totalSecondsInRange: TimeInterval = 0

    @Published public var isExporting: Bool = false
    @Published public var exportError: String? = nil
    @Published public var itemsToShare: [Any] = []
    @Published public var isShareSheetPresented: Bool = false

    public init() {}

    public func refreshReport(visits: [Visit], places: [Place]) {
        let interval = selectedRange.dateInterval(customStart: customStartDate, customEnd: customEndDate)

        self.placeAggregations = StayTrackUtils.aggregateTimeByPlace(
            visits: visits,
            places: places,
            in: interval
        )

        self.categoryAggregations = StayTrackUtils.aggregateTimeByCategory(
            visits: visits,
            places: places,
            in: interval
        )

        self.totalSecondsInRange = placeAggregations.reduce(0) { $0 + $1.totalSeconds }
    }

    // MARK: - Generación de Archivos para Compartir

    public func exportCSV(visits: [Visit], places: [Place]) {
        let visitDTOs = filterVisitsInRange(visits: visits).map { VisitDTO(from: $0) }
        let placeDTOs = places.map { PlaceDTO(from: $0) }

        let csvString = CSVExporter.generateCSV(visits: visitDTOs, places: placeDTOs)
        shareTextFile(content: csvString, filename: "StayTrack_Informe_\(dateSlug()).csv")
    }

    public func exportXLSX(visits: [Visit], places: [Place]) {
        let visitDTOs = filterVisitsInRange(visits: visits).map { VisitDTO(from: $0) }
        let placeDTOs = places.map { PlaceDTO(from: $0) }

        let xlsxData = XLSXExporter.generateXLSXData(visits: visitDTOs, places: placeDTOs)
        shareBinaryFile(data: xlsxData, filename: "StayTrack_Informe_\(dateSlug()).xlsx")
    }

    public func exportGPX(places: [Place]) {
        let placeDTOs = places.map { PlaceDTO(from: $0) }
        let gpxString = GPXExporter.generateGPX(places: placeDTOs)
        shareTextFile(content: gpxString, filename: "StayTrack_Lugares_\(dateSlug()).gpx")
    }

    public func exportKML(places: [Place]) {
        let placeDTOs = places.map { PlaceDTO(from: $0) }
        let kmlString = KMLExporter.generateKML(places: placeDTOs)
        shareTextFile(content: kmlString, filename: "StayTrack_Lugares_\(dateSlug()).kml")
    }

    public func exportMapImage(places: [Place]) async {
        guard !places.isEmpty else {
            self.exportError = "No hay lugares registrados para generar la imagen del mapa."
            return
        }

        self.isExporting = true
        defer { self.isExporting = false }

        do {
            let placeDTOs = places.map { PlaceDTO(from: $0) }
            let image = try await MapSnapshotGenerator.generateMapSnapshot(places: placeDTOs)
            guard let pngData = MapSnapshotGenerator.pngData(from: image) else {
                self.exportError = "Error al codificar imagen PNG."
                return
            }

            shareBinaryFile(data: pngData, filename: "StayTrack_Mapa_\(dateSlug()).png")
        } catch {
            self.exportError = "Error al generar mapa: \(error.localizedDescription)"
        }
    }

    // MARK: - Helpers de Archivos Temporales

    private func shareTextFile(content: String, filename: String) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
            self.itemsToShare = [tempURL]
            self.isShareSheetPresented = true
        } catch {
            self.exportError = "Error al escribir archivo: \(error.localizedDescription)"
        }
    }

    private func shareBinaryFile(data: Data, filename: String) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: tempURL)
            self.itemsToShare = [tempURL]
            self.isShareSheetPresented = true
        } catch {
            self.exportError = "Error al escribir archivo binario: \(error.localizedDescription)"
        }
    }

    private func filterVisitsInRange(visits: [Visit]) -> [Visit] {
        let interval = selectedRange.dateInterval(customStart: customStartDate, customEnd: customEndDate)
        return visits.filter { v in
            let end = v.fin ?? Date()
            return v.inicio < interval.end && end > interval.start
        }
    }

    private func dateSlug() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmm"
        return formatter.string(from: Date())
    }
}
