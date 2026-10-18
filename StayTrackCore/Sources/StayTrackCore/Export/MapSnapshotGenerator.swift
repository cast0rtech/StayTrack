import Foundation
import CoreLocation
import MapKit
import CoreGraphics
import ImageIO

#if canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage
public typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
public typealias PlatformImage = NSImage
public typealias PlatformColor = NSColor
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

            // 2. Dibujar pin marcador del lugar coloreado por categoría
            let pinRadius: CGFloat = place.isFavorite ? 14 : 11
            let pinRect = CGRect(
                x: point.x - pinRadius,
                y: point.y - pinRadius,
                width: pinRadius * 2,
                height: pinRadius * 2
            )

            let catColor = categoryColor(for: place.category)
            cgContext.saveGState()
            cgContext.setFillColor(catColor)
            cgContext.fillEllipse(in: pinRect)
            cgContext.setStrokeColor(place.isFavorite ? CGColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) : whiteColor)
            cgContext.setLineWidth(place.isFavorite ? 3.0 : 2.0)
            cgContext.strokeEllipse(in: pinRect)
            cgContext.restoreGState()

            // 3. Dibujar etiqueta con el nombre del lugar visible
            let placeName = place.name.isEmpty ? place.category.displayName : place.name
            let font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, 12, nil)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: PlatformColor.white
            ]
            let attrStr = NSAttributedString(string: placeName, attributes: attributes)
            let line = CTLineCreateWithAttributedString(attrStr)
            let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)

            let pillPaddingX: CGFloat = 8
            let pillPaddingY: CGFloat = 4
            let pillWidth = bounds.width + pillPaddingX * 2
            let pillHeight = bounds.height + pillPaddingY * 2
            let pillX = point.x - (pillWidth / 2.0)
            let pillY = point.y + pinRadius + 4

            // Fondo oscuro para garantizar contraste y visibilidad del texto
            cgContext.saveGState()
            let pillRect = CGRect(x: pillX, y: pillY, width: pillWidth, height: pillHeight)
            let path = CGPath(roundedRect: pillRect, cornerWidth: 6, cornerHeight: 6, transform: nil)
            cgContext.setFillColor(CGColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 0.85))
            cgContext.addPath(path)
            cgContext.fillPath()
            cgContext.setStrokeColor(catColor)
            cgContext.setLineWidth(1.0)
            cgContext.addPath(path)
            cgContext.strokePath()

            // Renderizar texto
            #if os(iOS)
            UIGraphicsPushContext(cgContext)
            attrStr.draw(at: CGPoint(x: pillX + pillPaddingX, y: pillY + pillPaddingY - 1))
            UIGraphicsPopContext()
            #elseif os(macOS)
            let textPos = CGPoint(x: pillX + pillPaddingX, y: pillY + pillPaddingY)
            cgContext.textPosition = textPos
            CTLineDraw(line, cgContext)
            #endif
            cgContext.restoreGState()
        }
    }

    private static func categoryColor(for category: PlaceCategory) -> CGColor {
        switch category {
        case .casa:
            return CGColor(red: 0.0, green: 0.89, blue: 1.0, alpha: 1.0) // Cian
        case .trabajo:
            return CGColor(red: 0.49, green: 0.30, blue: 1.0, alpha: 1.0) // Púrpura
        case .entrenamiento:
            return CGColor(red: 1.0, green: 0.32, blue: 0.32, alpha: 1.0) // Coral
        case .medico:
            return CGColor(red: 0.41, green: 0.94, blue: 0.68, alpha: 1.0) // Esmeralda
        case .otro:
            return CGColor(red: 1.0, green: 0.84, blue: 0.25, alpha: 1.0) // Ámbar
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
