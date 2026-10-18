import Foundation
import zlib

/// Generador nativo de archivos Microsoft Excel (.xlsx) OpenXML.
///
/// Decisión de arquitectura senior:
/// La biblioteca CoreXLSX mencionada comúnmente en la comunidad iOS es estrictamente de solo lectura
/// (parser de XML para leer archivos existentes). Para generar archivos .xlsx auténticos sin añadir
/// dependencias pesadas, inestables o de terceros, StayTrackCore implementa un generador OpenXML nativo
/// en Swift puro empaquetado mediante compresión ZIP estándar (RFC 1951 DEFLATE / zlib del sistema).
/// Esto garantiza 0 riesgos de supply-chain, compilación instantánea y generación de archivos
/// identificados y abiertos nativamente por Microsoft Excel, Apple Numbers y Google Sheets.
public struct XLSXExporter: Sendable {

    /// Genera los datos binarios de un archivo Excel .xlsx válido
    public static func generateXLSXData(
        visits: [VisitDTO],
        places: [PlaceDTO]
    ) -> Data {
        let placesMap = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) })
        let isoFormatter = ISO8601DateFormatter()

        // 1. [Content_Types].xml
        let contentTypesXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
          <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
          <Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
          <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
        </Types>
        """

        // 2. _rels/.rels
        let rootRelsXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """

        // 3. xl/workbook.xml
        let workbookXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheets>
            <sheet name="Estancias" sheetId="1" r:id="rId1"/>
            <sheet name="Lugares" sheetId="2" r:id="rId2"/>
          </sheets>
        </workbook>
        """

        // 4. xl/_rels/workbook.xml.rels
        let workbookRelsXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>
          <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        </Relationships>
        """

        // 5. xl/styles.xml
        let stylesXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <fonts count="2">
            <font><sz val="11"/><name val="Calibri"/></font>
            <font><b/><sz val="11"/><name val="Calibri"/></font>
          </fonts>
          <fills count="2">
            <fill><patternFill patternType="none"/></fill>
            <fill><patternFill patternType="gray125"/></fill>
          </fills>
          <borders count="1">
            <border><left/><right/><top/><bottom/><diagonal/></border>
          </borders>
          <cellStyleXfs count="1">
            <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
          </cellStyleXfs>
          <cellXfs count="2">
            <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
            <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0"/>
          </cellXfs>
        </styleSheet>
        """

        // 6. xl/worksheets/sheet1.xml (Estancias / Visits)
        var sheet1Rows: [String] = []

        // Header row (Estancias)
        let sheet1Headers = [
            "ID Visita", "Lugar", "Categoría", "Llegada", "Salida",
            "Duración (Minutos)", "Duración (Formato)", "Dispositivo",
            "Movimiento", "Latitud", "Longitud", "Estado"
        ]
        sheet1Rows.append(makeRowXML(rowIndex: 1, cells: sheet1Headers.map { (.string($0), isBold: true) }))

        var rowIndex = 2
        for visit in visits {
            let matchedPlace = visit.placeId.flatMap { placesMap[$0] }
            let placeName = matchedPlace?.name ?? "Lugar sin nombre"
            let categoryName = matchedPlace?.category.displayName ?? PlaceCategory.other.displayName
            let arrivalStr = isoFormatter.string(from: visit.arrivalDate)
            let departureStr = visit.departureDate.map { isoFormatter.string(from: $0) } ?? "En curso"
            let durationMinutes = visit.duration / 60.0
            let durationFormatted = formatDuration(visit.duration)

            let cells: [(CellValue, isBold: Bool)] = [
                (.string(visit.id.uuidString), false),
                (.string(placeName), false),
                (.string(categoryName), false),
                (.string(arrivalStr), false),
                (.string(departureStr), false),
                (.number(Double(round(10 * durationMinutes) / 10)), false),
                (.string(durationFormatted), false),
                (.string(visit.deviceSource.displayName), false),
                (.string(visit.isMovingDetected ? "Sí" : "No"), false),
                (.number(visit.latitude), false),
                (.number(visit.longitude), false),
                (.string(visit.isOngoing ? "En curso" : "Completada"), false)
            ]
            sheet1Rows.append(makeRowXML(rowIndex: rowIndex, cells: cells))
            rowIndex += 1
        }

        let sheet1XML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <sheetData>
            \(sheet1Rows.joined(separator: "\n    "))
          </sheetData>
        </worksheet>
        """

        // 7. xl/worksheets/sheet2.xml (Lugares / Places)
        var sheet2Rows: [String] = []
        let sheet2Headers = [
            "ID Lugar", "Nombre", "Categoría", "Favorito", "Icono SF",
            "Radio (m)", "Latitud", "Longitud", "Creado"
        ]
        sheet2Rows.append(makeRowXML(rowIndex: 1, cells: sheet2Headers.map { (.string($0), isBold: true) }))

        rowIndex = 2
        for place in places {
            let cells: [(CellValue, isBold: Bool)] = [
                (.string(place.id.uuidString), false),
                (.string(place.name), false),
                (.string(place.category.displayName), false),
                (.string(place.isFavorite ? "Sí" : "No"), false),
                (.string(place.icon), false),
                (.number(place.radius), false),
                (.number(place.latitude), false),
                (.number(place.longitude), false),
                (.string(isoFormatter.string(from: place.createdAt)), false)
            ]
            sheet2Rows.append(makeRowXML(rowIndex: rowIndex, cells: cells))
            rowIndex += 1
        }

        let sheet2XML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <sheetData>
            \(sheet2Rows.joined(separator: "\n    "))
          </sheetData>
        </worksheet>
        """

        // Empaquetar en archivo ZIP
        let entries = [
            ZipFileEntry(path: "[Content_Types].xml", string: contentTypesXML),
            ZipFileEntry(path: "_rels/.rels", string: rootRelsXML),
            ZipFileEntry(path: "xl/workbook.xml", string: workbookXML),
            ZipFileEntry(path: "xl/_rels/workbook.xml.rels", string: workbookRelsXML),
            ZipFileEntry(path: "xl/styles.xml", string: stylesXML),
            ZipFileEntry(path: "xl/worksheets/sheet1.xml", string: sheet1XML),
            ZipFileEntry(path: "xl/worksheets/sheet2.xml", string: sheet2XML)
        ]

        return ZipPackageWriter.createZip(entries: entries)
    }

    private enum CellValue {
        case string(String)
        case number(Double)
    }

    private static func makeRowXML(rowIndex: Int, cells: [(CellValue, isBold: Bool)]) -> String {
        var cellStrings: [String] = []
        for (colIdx, item) in cells.enumerated() {
            let colName = columnLetter(colIdx + 1)
            let cellRef = "\(colName)\(rowIndex)"
            let styleAttr = item.isBold ? " s=\"1\"" : ""

            switch item.0 {
            case .string(let str):
                let escaped = escapeXML(str)
                cellStrings.append("<c r=\"\(cellRef)\"\(styleAttr) t=\"inlineStr\"><is><t>\(escaped)</t></is></c>")
            case .number(let num):
                cellStrings.append("<c r=\"\(cellRef)\"\(styleAttr)><v>\(num)</v></c>")
            }
        }
        return "<row r=\"\(rowIndex)\">\(cellStrings.joined())</row>"
    }

    private static func columnLetter(_ columnNumber: Int) -> String {
        var n = columnNumber
        var result = ""
        while n > 0 {
            let rem = (n - 1) % 26
            result = String(UnicodeScalar(65 + rem)!) + result
            n = (n - 1) / 26
        }
        return result
    }

    private static func escapeXML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
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

// MARK: - Soporte ZIP nativo interno

struct ZipFileEntry {
    let path: String
    let data: Data

    init(path: String, data: Data) {
        self.path = path
        self.data = data
    }

    init(path: String, string: String) {
        self.path = path
        self.data = Data(string.utf8)
    }
}

struct ZipPackageWriter {
    static func createZip(entries: [ZipFileEntry]) -> Data {
        var zipData = Data()
        var centralDirectory = Data()
        var centralDirEntriesCount: UInt16 = 0

        for entry in entries {
            let filenameBytes = Array(entry.path.utf8)
            let filenameLength = UInt16(filenameBytes.count)

            let crc: UInt32 = entry.data.withUnsafeBytes { rawBuffer in
                guard let baseAddress = rawBuffer.baseAddress else { return 0 }
                return UInt32(zlib.crc32(0, baseAddress.assumingMemoryBound(to: Bytef.self), uInt(entry.data.count)))
            }

            var compressedData: Data = entry.data
            var compressionMethod: UInt16 = 0 // STORE

            if !entry.data.isEmpty, let deflated = deflateData(entry.data) {
                compressedData = deflated
                compressionMethod = 8 // DEFLATE
            }

            let localHeaderOffset = UInt32(zipData.count)

            // Local header
            var localHeader = Data()
            localHeader.append(contentsOf: [0x50, 0x4b, 0x03, 0x04])
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt16(20).littleEndian) { Array($0) })
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt16(0x0800).littleEndian) { Array($0) })
            localHeader.append(contentsOf: withUnsafeBytes(of: compressionMethod.littleEndian) { Array($0) })
            localHeader.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
            localHeader.append(contentsOf: withUnsafeBytes(of: crc.littleEndian) { Array($0) })
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt32(compressedData.count).littleEndian) { Array($0) })
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt32(entry.data.count).littleEndian) { Array($0) })
            localHeader.append(contentsOf: withUnsafeBytes(of: filenameLength.littleEndian) { Array($0) })
            localHeader.append(contentsOf: [0x00, 0x00])
            localHeader.append(contentsOf: filenameBytes)

            zipData.append(localHeader)
            zipData.append(compressedData)

            // Central directory header
            var cdHeader = Data()
            cdHeader.append(contentsOf: [0x50, 0x4b, 0x01, 0x02])
            cdHeader.append(contentsOf: withUnsafeBytes(of: UInt16(20).littleEndian) { Array($0) })
            cdHeader.append(contentsOf: withUnsafeBytes(of: UInt16(20).littleEndian) { Array($0) })
            cdHeader.append(contentsOf: withUnsafeBytes(of: UInt16(0x0800).littleEndian) { Array($0) })
            cdHeader.append(contentsOf: withUnsafeBytes(of: compressionMethod.littleEndian) { Array($0) })
            cdHeader.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
            cdHeader.append(contentsOf: withUnsafeBytes(of: crc.littleEndian) { Array($0) })
            cdHeader.append(contentsOf: withUnsafeBytes(of: UInt32(compressedData.count).littleEndian) { Array($0) })
            cdHeader.append(contentsOf: withUnsafeBytes(of: UInt32(entry.data.count).littleEndian) { Array($0) })
            cdHeader.append(contentsOf: withUnsafeBytes(of: filenameLength.littleEndian) { Array($0) })
            cdHeader.append(contentsOf: [0x00, 0x00])
            cdHeader.append(contentsOf: [0x00, 0x00])
            cdHeader.append(contentsOf: [0x00, 0x00])
            cdHeader.append(contentsOf: [0x00, 0x00])
            cdHeader.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
            cdHeader.append(contentsOf: withUnsafeBytes(of: localHeaderOffset.littleEndian) { Array($0) })
            cdHeader.append(contentsOf: filenameBytes)

            centralDirectory.append(cdHeader)
            centralDirEntriesCount += 1
        }

        let centralDirOffset = UInt32(zipData.count)
        let centralDirSize = UInt32(centralDirectory.count)

        zipData.append(centralDirectory)

        // End of central directory record
        var eocd = Data()
        eocd.append(contentsOf: [0x50, 0x4b, 0x05, 0x06])
        eocd.append(contentsOf: [0x00, 0x00])
        eocd.append(contentsOf: [0x00, 0x00])
        eocd.append(contentsOf: withUnsafeBytes(of: centralDirEntriesCount.littleEndian) { Array($0) })
        eocd.append(contentsOf: withUnsafeBytes(of: centralDirEntriesCount.littleEndian) { Array($0) })
        eocd.append(contentsOf: withUnsafeBytes(of: centralDirSize.littleEndian) { Array($0) })
        eocd.append(contentsOf: withUnsafeBytes(of: centralDirOffset.littleEndian) { Array($0) })
        eocd.append(contentsOf: [0x00, 0x00])

        zipData.append(eocd)
        return zipData
    }

    private static func deflateData(_ input: Data) -> Data? {
        var stream = z_stream()
        let windowBits = -MAX_WBITS
        guard deflateInit2_(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, windowBits, 8, Z_DEFAULT_STRATEGY, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            return nil
        }
        defer { deflateEnd(&stream) }

        var output = Data(count: max(128, input.count))
        var status = Z_OK

        input.withUnsafeBytes { rawIn in
            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: rawIn.bindMemory(to: Bytef.self).baseAddress)
            stream.avail_in = uInt(input.count)

            while status == Z_OK {
                let currentCount = output.count
                let totalOut = Int(stream.total_out)
                let remaining = currentCount - totalOut

                if remaining < 128 {
                    output.count = currentCount * 2
                }

                let outputCount = output.count
                output.withUnsafeMutableBytes { rawOut in
                    let base = rawOut.bindMemory(to: Bytef.self).baseAddress!
                    stream.next_out = base.advanced(by: totalOut)
                    stream.avail_out = uInt(outputCount - totalOut)
                    status = deflate(&stream, Z_FINISH)
                }
            }
        }

        guard status == Z_STREAM_END else { return nil }
        output.count = Int(stream.total_out)
        return output
    }
}
