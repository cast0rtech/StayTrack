import SwiftUI
import Charts
import StayTrackCore

/// Pantalla de Informes por rango de fechas con gráficos Swift Charts y exportación multiformato.
struct ExportReportsView: View {
    @ObservedObject var trackingViewModel: iOSTrackingViewModel
    @StateObject private var exportViewModel = ExportReportViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Selector de Rango de Fechas
                    rangeSelectorSection

                    // 2. Tarjeta Resumen Total
                    totalSummaryCard

                    // 3. Gráficos Swift Charts (Estilo Dashboard)
                    if !exportViewModel.placeAggregations.isEmpty {
                        chartsSection
                    }

                    // 4. Tabla Detallada por Lugares
                    placesDataTableSection

                    // 5. Botones de Exportación
                    exportButtonsSection
                }
                .padding()
            }
            .navigationTitle("Informes")
            .sheet(isPresented: $exportViewModel.isShareSheetPresented) {
                ActivityViewController(activityItems: exportViewModel.itemsToShare)
            }
            .onAppear {
                exportViewModel.refreshReport(
                    visits: trackingViewModel.allVisits,
                    places: trackingViewModel.allPlaces
                )
            }
            .onChange(of: exportViewModel.selectedRange) { _, _ in
                exportViewModel.refreshReport(
                    visits: trackingViewModel.allVisits,
                    places: trackingViewModel.allPlaces
                )
            }
            .onChange(of: exportViewModel.customStartDate) { _, _ in
                if exportViewModel.selectedRange == .custom {
                    exportViewModel.refreshReport(
                        visits: trackingViewModel.allVisits,
                        places: trackingViewModel.allPlaces
                    )
                }
            }
            .onChange(of: exportViewModel.customEndDate) { _, _ in
                if exportViewModel.selectedRange == .custom {
                    exportViewModel.refreshReport(
                        visits: trackingViewModel.allVisits,
                        places: trackingViewModel.allPlaces
                    )
                }
            }
        }
    }

    // MARK: - Selector de Rango

    private var rangeSelectorSection: some View {
        VStack(spacing: 12) {
            Picker("Rango", selection: $exportViewModel.selectedRange) {
                ForEach(ReportPresetRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)

            if exportViewModel.selectedRange == .custom {
                HStack(spacing: 12) {
                    DatePicker("Desde", selection: $exportViewModel.customStartDate, displayedComponents: .date)
                    DatePicker("Hasta", selection: $exportViewModel.customEndDate, displayedComponents: .date)
                }
                .font(.footnote)
            }
        }
    }

    // MARK: - Tarjeta Resumen Total

    private var totalSummaryCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("TIEMPO TOTAL REGISTRADO")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Text(StayTrackUtils.formatDuration(exportViewModel.totalSecondsInRange))
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("\(exportViewModel.placeAggregations.count) lugares visitados en este periodo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    // MARK: - Sección de Gráficos Swift Charts

    private var chartsSection: some View {
        VStack(spacing: 16) {
            // Gráfico 1: Tiempo por Lugar (Barras horizontales)
            VStack(alignment: .leading, spacing: 10) {
                Text("Tiempo por Lugar")
                    .font(.headline)
                    .foregroundStyle(.white)

                Chart(exportViewModel.placeAggregations.prefix(5)) { item in
                    BarMark(
                        x: .value("Horas", item.hours),
                        y: .value("Lugar", item.placeName)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [item.category.accentColor, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(6)
                }
                .frame(height: 160)
                .chartXAxis {
                    AxisMarks(position: .bottom) { _ in
                        AxisValueLabel()
                    }
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

            // Gráfico 2: Tiempo por Categoría
            if !exportViewModel.categoryAggregations.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Distribución por Categoría")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Chart(exportViewModel.categoryAggregations) { cat in
                        SectorMark(
                            angle: .value("Horas", cat.hours),
                            innerRadius: .ratio(0.55),
                            angularInset: 2.0
                        )
                        .foregroundStyle(cat.category.accentColor)
                        .cornerRadius(4)
                    }
                    .frame(height: 180)

                    // Leyenda de categorías
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                        ForEach(exportViewModel.categoryAggregations) { cat in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(cat.category.accentColor)
                                    .frame(width: 8, height: 8)
                                Text(cat.category.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(StayTrackUtils.formatDuration(cat.totalSeconds))
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            }
                        }
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
        }
    }

    // MARK: - Tabla de Lugares Estilo Dashboard

    private var placesDataTableSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Detalle del Periodo")
                .font(.headline)
                .foregroundStyle(.white)

            if exportViewModel.placeAggregations.isEmpty {
                Text("No hay registros en el rango seleccionado.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(exportViewModel.placeAggregations) { item in
                    HStack {
                        Image(systemName: item.category.defaultIcon)
                            .font(.subheadline.bold())
                            .foregroundStyle(item.category.accentColor)
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.06), in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.placeName)
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                            Text(item.category.displayName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(StayTrackUtils.formatDuration(item.totalSeconds))
                            .font(.subheadline.bold())
                            .foregroundStyle(.cyan)
                    }
                    .padding(.vertical, 4)
                    Divider()
                        .background(Color.white.opacity(0.08))
                }
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

    // MARK: - Botones de Exportación

    private var exportButtonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exportar Informes y Datos")
                .font(.headline)
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                // Exportar CSV
                exportButton(
                    title: "Exportar CSV",
                    icon: "doc.text.fill",
                    gradientColors: [.blue, .cyan]
                ) {
                    exportViewModel.exportCSV(
                        visits: trackingViewModel.allVisits,
                        places: trackingViewModel.allPlaces
                    )
                }

                // Exportar XLSX Real
                exportButton(
                    title: "Excel .xlsx",
                    icon: "tablecells.fill",
                    gradientColors: [.green, .mint]
                ) {
                    exportViewModel.exportXLSX(
                        visits: trackingViewModel.allVisits,
                        places: trackingViewModel.allPlaces
                    )
                }

                // Exportar Mapa PNG
                exportButton(
                    title: "Mapa PNG",
                    icon: "map.fill",
                    gradientColors: [.purple, .indigo]
                ) {
                    Task {
                        await exportViewModel.exportMapImage(places: trackingViewModel.allPlaces)
                    }
                }

                // Exportar GPX / KML
                exportButton(
                    title: "GPX Waypoints",
                    icon: "location.north.circle.fill",
                    gradientColors: [.orange, .yellow]
                ) {
                    exportViewModel.exportGPX(places: trackingViewModel.allPlaces)
                }

                exportButton(
                    title: "KML (Google Earth)",
                    icon: "globe.americas.fill",
                    gradientColors: [.teal, .cyan]
                ) {
                    exportViewModel.exportKML(places: trackingViewModel.allPlaces)
                }
            }
        }
        .padding(.top, 8)
    }

    private func exportButton(
        title: String,
        icon: String,
        gradientColors: [Color],
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .shadow(color: gradientColors.first?.opacity(0.3) ?? .clear, radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }
}
