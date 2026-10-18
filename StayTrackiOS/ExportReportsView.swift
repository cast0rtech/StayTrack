import SwiftUI
import StayTrackCore

/// Centro de exportación de informes multiformato.
/// Permite generar y compartir archivos CSV, .xlsx auténtico de Excel,
/// imagen de mapa en alta resolución con lugares marcados, GPX y KML.
public struct ExportReportsView: View {
    @ObservedObject var viewModel: iOSTrackingViewModel
    @State private var activeExportURL: URL?
    @State private var isExportingMap: Bool = false
    @State private var mapExportSuccess: Bool = false
    @State private var showingShareSheet: Bool = false

    public init(viewModel: iOSTrackingViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Cabecera descriptiva
                    headerDescriptionCard

                    // Tarjetas de exportación de formatos
                    exportOptionCard(
                        format: .csv,
                        title: "Exportar CSV (.csv)",
                        subtitle: "Compatible con hojas de cálculo y scripts de análisis (UTF-8 con BOM).",
                        badge: "RFC-4180",
                        color: .green
                    )

                    exportOptionCard(
                        format: .xlsx,
                        title: "Exportar Excel Real (.xlsx)",
                        subtitle: "Libro binario OpenXML nativo con hojas para Estancias y Lugares.",
                        badge: "Excel 2007+",
                        color: .cyan
                    )

                    mapSnapshotExportCard

                    exportOptionCard(
                        format: .gpx,
                        title: "Exportar GPX (.gpx)",
                        subtitle: "Formato GPS Exchange con todos los lugares y estancias como waypoints.",
                        badge: "GPX 1.1",
                        color: .purple
                    )

                    exportOptionCard(
                        format: .kml,
                        title: "Exportar KML (.kml)",
                        subtitle: "Archivo Keyhole Markup Language para visualizar en Google Earth.",
                        badge: "KML 2.2",
                        color: .orange
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.06, blue: 0.11), Color(red: 0.02, green: 0.03, blue: 0.06)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Exportar")
            .sheet(isPresented: $showingShareSheet) {
                if let url = activeExportURL {
                    ShareSheet(activityItems: [url])
                } else if let img = viewModel.exportedMapImage {
                    ShareSheet(activityItems: [img])
                }
            }
        }
    }

    private var headerDescriptionCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "square.and.arrow.up.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.cyan)

            VStack(alignment: .leading, spacing: 2) {
                Text("Exportaciones e Informes")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Text("\(viewModel.visits.count) estancias y \(viewModel.places.count) lugares disponibles para exportar.")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func exportOptionCard(
        format: ExportFormat,
        title: String,
        subtitle: String,
        badge: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: format.sfSymbol)
                    .font(.system(size: 20))
                    .foregroundColor(color)

                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Text(badge)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(color.opacity(0.2))
                    .foregroundColor(color)
                    .clipShape(Capsule())
            }

            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(.gray)

            Button {
                if let url = viewModel.exportFile(format: format) {
                    self.activeExportURL = url
                    self.showingShareSheet = true
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 12))
                    Text("Generar y Compartir")
                        .font(.system(size: 13, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(color.opacity(0.2))
                .foregroundColor(color)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(color.opacity(0.5), lineWidth: 1)
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var mapSnapshotExportCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "map.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.pink)

                Text("Imagen de Mapa con Lugares (.png)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Text("MKMapSnapshot")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.pink.opacity(0.2))
                    .foregroundColor(.pink)
                    .clipShape(Capsule())
            }

            Text("Renderiza un mapa en alta resolución con marcadores estilizados y círculos translúcidos para el radio de cada lugar.")
                .font(.system(size: 12))
                .foregroundColor(.gray)

            if let previewImg = viewModel.exportedMapImage {
                Image(uiImage: previewImg)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.cyan.opacity(0.4), lineWidth: 1)
                    )
            }

            Button {
                Task {
                    isExportingMap = true
                    let img = await viewModel.exportMapImageSnapshot()
                    isExportingMap = false
                    if img != nil {
                        activeExportURL = nil
                        showingShareSheet = true
                    }
                }
            } label: {
                HStack {
                    if isExportingMap {
                        ProgressView()
                            .tint(.pink)
                    } else {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 12))
                    }
                    Text(isExportingMap ? "Renderizando mapa..." : "Generar Captura de Mapa")
                        .font(.system(size: 13, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.pink.opacity(0.2))
                .foregroundColor(.pink)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.pink.opacity(0.5), lineWidth: 1)
                )
            }
            .disabled(isExportingMap || viewModel.places.isEmpty)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// MARK: - UIActivityViewController Bridge

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
