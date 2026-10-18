import SwiftUI
import Charts
import StayTrackCore

/// Pantalla principal del Dashboard con estética futurista,
/// tarjetas con glassmorphism (.ultraThinMaterial), acentos vibrantes cian/púrpura
/// y visualizaciones dinámicas con Swift Charts.
public struct DashboardView: View {
    @ObservedObject var viewModel: iOSTrackingViewModel
    @State private var isPulsing: Bool = false

    public init(viewModel: iOSTrackingViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Barra de Estado de Conectividad y Prioridad
                    deviceStatusBar

                    // 2. Tarjeta Futurista de Estancia Activa
                    activeStayCard

                    // 3. Indicadores Clave de Desempeño (KPIs)
                    kpiCardsRow

                    // 4. Swift Charts: Distribución por Categoría
                    categoryDistributionChart

                    // 5. Swift Charts: Tiempo por Lugar
                    placesTimeChart
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
            .navigationTitle("StayTrack")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.syncWithWatch()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.cyan)
                    }
                }
            }
            .onAppear {
                isPulsing = true
            }
        }
    }

    // MARK: - Subcomponentes

    private var deviceStatusBar: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(viewModel.isWatchConnected ? Color.green : Color.cyan)
                .frame(width: 10, height: 10)
                .scaleEffect(isPulsing ? 1.3 : 1.0)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isPulsing)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.watchSyncStateText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(viewModel.isWatchConnected ? "El Apple Watch tiene prioridad de registro de estancia" : "Registrando automáticamente desde el iPhone")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }

            Spacer()

            Image(systemName: viewModel.isWatchConnected ? "applewatch.radiowaves.left.and.right" : "iphone")
                .font(.system(size: 18))
                .foregroundColor(viewModel.isWatchConnected ? .green : .cyan)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.4), Color.purple.opacity(0.2)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    private var activeStayCard: some View {
        VStack(spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(.cyan)
                    Text("ESTANCIA ACTIVA")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(.cyan)
                }

                Spacer()

                if let active = viewModel.activeVisit {
                    Text(active.deviceSource.displayName.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(active.deviceSource == .watch ? Color.purple.opacity(0.3) : Color.blue.opacity(0.3))
                        .foregroundColor(active.deviceSource == .watch ? .purple : .cyan)
                        .clipShape(Capsule())
                }
            }

            if let place = viewModel.currentPlace {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.cyan.opacity(0.3), Color.purple.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 58, height: 58)

                        Image(systemName: place.icon)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.name)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)

                        Text("Radio de detección: \(Int(place.radius)) metros")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }

                    Spacer()
                }
            } else if viewModel.activeVisit != nil {
                HStack(spacing: 16) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 32))
                        .foregroundColor(.cyan)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Punto Ancla Confirmado")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)

                        Text("Zona no catalogada (> 2 min dentro del radio)")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
            } else {
                HStack(spacing: 14) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 28))
                        .foregroundColor(.gray)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("En Tránsito / Desplazamiento")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        Text("Permanece > 2 min en una zona para check-in automático")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
            }

            // Cronómetro grande futurista
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TIEMPO ACUMULADO")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(.gray)

                    Text(viewModel.elapsedTimeString)
                        .font(.system(size: 38, weight: .heavy, design: .monospaced))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .cyan, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                Spacer()
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.6), Color.purple.opacity(0.4), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color.cyan.opacity(0.15), radius: 20, x: 0, y: 10)
        )
    }

    private var kpiCardsRow: some View {
        HStack(spacing: 12) {
            kpiCard(
                title: "LUGARES",
                value: "\(viewModel.places.count)",
                icon: "mappin.circle.fill",
                color: .cyan
            )

            kpiCard(
                title: "ESTANCIAS",
                value: "\(viewModel.visits.count)",
                icon: "clock.arrow.circlepath",
                color: .purple
            )

            kpiCard(
                title: "TOTAL",
                value: formatTotalHours(viewModel.totalTrackedSeconds),
                icon: "chart.bar.fill",
                color: .pink
            )
        }
    }

    private func kpiCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(title)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundColor(.gray)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Gráficos Swift Charts

    private var categoryDistributionChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("DISTRIBUCIÓN POR CATEGORÍA")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(.cyan)
                Spacer()
            }

            if viewModel.statsByCategory.allSatisfy({ $0.totalSeconds == 0 }) {
                Text("Sin registros de estancia todavía.")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(viewModel.statsByCategory) { stat in
                    BarMark(
                        x: .value("Horas", stat.hours),
                        y: .value("Categoría", stat.category.displayName)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: stat.category.accentHex), Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(6)
                }
                .frame(height: 180)
                .chartXAxis {
                    AxisMarks(position: .bottom) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                            .foregroundStyle(Color.gray.opacity(0.3))
                        AxisValueLabel()
                            .foregroundStyle(Color.gray)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel()
                            .foregroundStyle(Color.white)
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
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private var placesTimeChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TIEMPO POR LUGAR")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(.purple)
                Spacer()
            }

            if viewModel.statsByPlace.isEmpty {
                Text("Sin estancias registradas.")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(viewModel.statsByPlace.prefix(5)) { item in
                    SectorMark(
                        angle: .value("Duración", max(0.1, item.hours)),
                        innerRadius: .ratio(0.6),
                        angularInset: 2
                    )
                    .cornerRadius(4)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: item.category.accentHex), Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
                .frame(height: 180)

                // Leyenda
                VStack(spacing: 6) {
                    ForEach(viewModel.statsByPlace.prefix(4)) { item in
                        HStack {
                            Circle()
                                .fill(Color(hex: item.category.accentHex))
                                .frame(width: 8, height: 8)
                            Text(item.placeName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Text(String(format: "%.1f h", item.hours))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func formatTotalHours(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex.replacingOccurrences(of: "#", with: ""))
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
