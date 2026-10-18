import Foundation
import CoreLocation
import MapKit
import CoreGraphics
import ImageIO

#if canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
public typealias PlatformImage = NSImage
#endif

/// Generador de capturas de mapa en alta resolución con lugares marcados y radios visualizados.
public struct MapSnapshotGenerator: Sendable {

    /// Genera una imagen del mapa centrada en los lugares proporcionados
    public static func generateMapSnapshot(
        places: [PlaceDTO],
        size: CGSize = CGSize(width: 1200, height: 800)
    ) async throws -> PlatformImage {
        guard !places.isEmpty else {
            throw MapSnapshotError.noPlacesProvided
        }

        let region = calculateRegion(for: places)
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = size

        let snapshotter = MKMapSnapshotter(options: options)
        let snapshot = try await snapshotter.start()

        #if os(iOS)
        let format = UIGraphicsImageRendererFormat.default()
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let finalImage = renderer.image { context in
            snapshot.image.draw(at: .zero)
            let cgContext = context.cgContext
            drawOverlays(places: places, snapshot: snapshot, cgContext: cgContext)
        }
        return finalImage
        #elseif os(watchOS)
        return snapshot.image
        #elseif os(macOS)
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        snapshot.image.draw(in: NSRect(origin: .zero, size: size))
        if let cgContext = NSGraphicsContext.current?.cgContext {
            drawOverlays(places: places, snapshot: snapshot, cgContext: cgContext)
        }
        newImage.unlockFocus()
        return newImage
        #endif
    }

    private static func drawOverlays(places: [PlaceDTO], snapshot: MKMapSnapshotter.Snapshot, cgContext: CGContext) {
        let cyanFill = CGColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 0.2)
        let cyanStroke = CGColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 0.8)
        let favoriteFill = CGColor(red: 1.0, green: 0.2, blue: 0.5, alpha: 1.0)
        let standardFill = CGColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0)
        let whiteColor = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)

        for place in places {
            let coordinate = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
            let point = snapshot.point(for: coordinate)

            // 1. Dibujar círculo del radio de detección
            let edgeCoord = coordinateOffset(from: coordinate, distanceMeters: place.radius)
            let edgePoint = snapshot.point(for: edgeCoord)
            let pixelRadius = hypot(edgePoint.x - point.x, edgePoint.y - point.y)

            cgContext.saveGState()
            let circleRect = CGRect(
                x: point.x - pixelRadius,
                y: point.y - pixelRadius,
                width: pixelRadius * 2,
                height: pixelRadius * 2
            )
            cgContext.setFillColor(cyanFill)
            cgContext.fillEllipse(in: circleRect)
            cgContext.setStrokeColor(cyanStroke)
            cgContext.setLineWidth(1.5)
            cgContext.strokeEllipse(in: circleRect)
            cgContext.restoreGState()

            // 2. Dibujar pin marcador del lugar
            let pinRadius: CGFloat = place.isFavorite ? 14 : 10
            let pinRect = CGRect(
                x: point.x - pinRadius,
                y: point.y - pinRadius,
                width: pinRadius * 2,
                height: pinRadius * 2
            )

            cgContext.saveGState()
            cgContext.setFillColor(place.isFavorite ? favoriteFill : standardFill)
            cgContext.fillEllipse(in: pinRect)
            cgContext.setStrokeColor(whiteColor)
            cgContext.setLineWidth(2.5)
            cgContext.strokeEllipse(in: pinRect)
            cgContext.restoreGState()
        }
    }

    /// Convierte la PlatformImage en datos binarios PNG
    public static func pngData(from image: PlatformImage) -> Data? {
        #if os(iOS)
        return image.pngData()
        #elseif os(watchOS)
        guard let cgImage = image.cgImage else { return nil }
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, "public.png" as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutableData as Data
        #elseif os(macOS)
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
        #endif
    }

    private static func calculateRegion(for places: [PlaceDTO]) -> MKCoordinateRegion {
        var minLat = places.first!.latitude
        var maxLat = places.first!.latitude
        var minLon = places.first!.longitude
        var maxLon = places.first!.longitude

        for p in places {
            minLat = min(minLat, p.latitude)
            maxLat = max(maxLat, p.latitude)
            minLon = min(minLon, p.longitude)
            maxLon = max(maxLon, p.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2.0,
            longitude: (minLon + maxLon) / 2.0
        )
        let latDelta = max(0.015, (maxLat - minLat) * 1.5)
        let lonDelta = max(0.015, (maxLon - minLon) * 1.5)

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
    }

    private static func coordinateOffset(from coord: CLLocationCoordinate2D, distanceMeters: Double) -> CLLocationCoordinate2D {
        let earthRadius = 6378137.0
        let dLat = (distanceMeters / earthRadius) * (180.0 / .pi)
        return CLLocationCoordinate2D(latitude: coord.latitude + dLat, longitude: coord.longitude)
    }

    public enum MapSnapshotError: LocalizedError {
        case noPlacesProvided
        case renderingFailed

        public var errorDescription: String? {
            switch self {
            case .noPlacesProvided:
                return "No hay lugares para incluir en la captura del mapa."
            case .renderingFailed:
                return "Error al renderizar la imagen del mapa."
            }
        }
    }
}
