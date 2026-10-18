import SwiftUI
import Charts
import StayTrackCore

/// Pantalla principal (Dashboard) de StayTrack iOS.
struct DashboardView: View {
    @ObservedObject var viewModel: iOSTrackingViewModel
    @State private var liveTimerString: String = "0m"
    @State private var timer: Timer?

    var todayVisits: [Visit] {
        let calendar = Calendar.current
        return viewModel.allVisits.filter { calendar.isDateInToday($0.inicio) }
    }

    var totalSecondsToday: TimeInterval {
        todayVisits.reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Tarjeta Hero: Estado de Conexión y Prioridad
                    connectionStatusHeroCard

                    // 2. Tarjetas de Métricas Rápidas
                    metricsRow

                    // 3. Actividad Reciente
                    recentActivitySection
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .onAppear {
                startLiveTimer()
            }
            .onDisappear {
                timer?.invalidate()
            }
        }
    }

    // MARK: - Tarjeta Hero de Conexión y Estado

    private var connectionStatusHeroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(viewModel.isWatchConnected ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)
                    .shadow(color: (viewModel.isWatchConnected ? Color.green : Color.orange).opacity(0.8), radius: 4)

                Text(viewModel.isWatchConnected ? "APPLE WATCH CONECTADO" : "MODO RESPALDO (IPHONE)")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)

                Spacer()

                Image(systemName: viewModel.isWatchConnected ? "applewatch" : "iphone")
                    .font(.subheadline)
                    .foregroundStyle(viewModel.isWatchConnected ? .green : .orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.currentPhoneStayDescription)
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text(viewModel.isWatchConnected
                     ? "El reloj tiene prioridad absoluta en la detección de estancias y movimiento."
                     : "El iPhone registrará tus estancias de forma autónoma hasta que el reloj se reconecte.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if viewModel.isWatchConnected {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.cyan)
                    Text("Reconciliación de datos activa")
                        .font(.caption.bold())
                        .foregroundStyle(.cyan)
                }
                .padding(.top, 2)
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
                                colors: [Color.cyan.opacity(0.4), Color.purple.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    // MARK: - Fila de Métricas Rápidas

    private var metricsRow: some View {
        HStack(spacing: 12) {
            metricCard(
                title: "Tiempo Hoy",
                value: StayTrackUtils.formatDuration(totalSecondsToday),
                icon: "clock.fill",
                gradient: [.cyan, .blue]
            )

            metricCard(
                title: "Estancias Hoy",
                value: "\(todayVisits.count)",
                icon: "mappin.and.ellipse",
                gradient: [.purple, .indigo]
            )

            metricCard(
                title: "Favoritos",
                value: "\(viewModel.favoritePlaces.count)",
                icon: "star.fill",
                gradient: [.orange, .yellow]
            )
        }
    }

    private func metricCard(title: String, value: String, icon: String, gradient: [Color]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(
                    LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(.white)
                Text(title)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    // MARK: - Sección de Actividad Reciente

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Actividad Reciente")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
            }

            if viewModel.allVisits.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "hourglass.badge.plus")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Esperando registros del reloj o del teléfono")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 14))
            } else {
                ForEach(viewModel.allVisits.prefix(4)) { visit in
                    HStack(spacing: 12) {
                        Image(systemName: visit.place?.categoria.defaultIcon ?? "mappin.and.ellipse")
                            .font(.headline)
                            .foregroundStyle(visit.place?.categoria.accentColor ?? .cyan)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.06), in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(visit.place?.nombre.isEmpty == false ? visit.place!.nombre : "Lugar detectado")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                            Text(StayTrackUtils.formatInterval(start: visit.inicio, end: visit.fin))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(StayTrackUtils.formatDuration(visit.duration))
                                .font(.subheadline.bold())
                                .foregroundStyle(.cyan)

                            HStack(spacing: 3) {
                                Image(systemName: visit.origen == .watch ? "applewatch" : "iphone")
                                    .font(.system(size: 8))
                                Text(visit.origen.displayName)
                                    .font(.system(size: 8))
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func startLiveTimer() {
        self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                // Actualiza vista cada segundo si hay visitas en curso
            }
        }
    }
}
