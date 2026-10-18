import SwiftUI
import SwiftData
import StayTrackCore

/// Pantalla principal de StayTrack Watch.
///
/// Diseño visual conforme a AGENTS.md:
/// - Dark mode first con acentos vibrantes (cian, morado, azul).
/// - Glassmorphism sutil (.ultraThinMaterial) en tarjetas de alta legibilidad.
/// - Texto grande y jerarquía clara pensada para pantallas de Apple Watch.
/// - Micro-animación suave al confirmar o cerrar un check-in.
public struct WatchContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = WatchTrackingViewModel()
    @State private var showFavoriteSheet: Bool = false
    @State private var pulseAnimation: Bool = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                // Fondo oscuro ambiental
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        // 1. Tarjeta Hero: Estado Actual
                        currentStateHeroCard

                        // 2. Sección: Visitas Recientes
                        recentVisitsSection

                        // 3. Accesos Rápidos: Lugares y Ajustes
                        HStack(spacing: 8) {
                            NavigationLink {
                                WatchPlacesListView(viewModel: viewModel)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "mappin.and.ellipse")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.cyan)
                                    Text("Lugares")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                WatchSettingsView(viewModel: viewModel)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.purple)
                                    Text("Ajustes")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 16)
                }

                // 4. Micro-animación flotante de celebración de Check-in
                if viewModel.showCheckInCelebration {
                    celebrationOverlay
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(100)
                }
            }
            .navigationTitle("StayTrack")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showFavoriteSheet) {
                CreateFavoriteSheet(viewModel: viewModel)
            }
            .onAppear {
                viewModel.setModelContext(modelContext)
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                }
                if viewModel.authorizationStatus == .notDetermined {
                    viewModel.requestAuthorization()
                } else {
                    viewModel.startTracking()
                }
            }
        }
    }

    // MARK: - Tarjeta de Estado Actual (Hero Card)

    private var currentStateHeroCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cabecera con indicador pulsante
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.isStationary ? Color.green : Color.cyan)
                    .frame(width: 8, height: 8)
                    .scaleEffect(pulseAnimation ? 1.25 : 0.85)
                    .shadow(color: (viewModel.isStationary ? Color.green : Color.cyan).opacity(0.8), radius: 4)

                Text(viewModel.isStationary ? "ESTANCIA ACTIVA" : "ESTADO ACTUAL")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)

                Spacer()

                Image(systemName: "applewatch")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            // Título principal en texto grande
            Text(viewModel.currentPlaceName)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // Contador de tiempo y descripción de actividad
            HStack(spacing: 6) {
                if viewModel.isStationary, let since = viewModel.currentVisitSince {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.cyan)

                    Text("Desde \(formatTime(since))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text("•")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)

                    Text(viewModel.elapsedTimeString)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.cyan)
                } else {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 11))
                        .foregroundStyle(.cyan)

                    Text(viewModel.motionDetector.currentActivityTitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            // Botón rápido para guardar como favorito
            Button {
                showFavoriteSheet = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.yellow)
                    Text("Crear Favorito")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    LinearGradient(
                        colors: [.cyan.opacity(0.4), .purple.opacity(0.4)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 8)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [.cyan.opacity(0.5), .purple.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    // MARK: - Sección de Visitas Recientes

    private var recentVisitsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Estancias recientes")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            if viewModel.recentVisits.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "hourglass.bottomhalf.filled")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                        Text("Esperando primer check-in (> 2 min)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 12)
                    Spacer()
                }
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            } else {
                ForEach(viewModel.recentVisits.prefix(5), id: \.id) { visit in
                    HStack(spacing: 8) {
                        // Icono de categoría
                        Image(systemName: visit.place?.categoria.defaultIcon ?? "mappin.and.ellipse")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(visit.place?.categoria.accentColor ?? .cyan)
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.08), in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(visit.place?.nombre.isEmpty == false ? visit.place!.nombre : "Zona detectada")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Text(StayTrackUtils.formatInterval(start: visit.inicio, end: visit.fin))
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(StayTrackUtils.formatDuration(visit.duration))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.cyan)
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    // MARK: - Micro-Animación de Celebración

    private var celebrationOverlay: some View {
        VStack {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.yellow)

                VStack(alignment: .leading, spacing: 1) {
                    Text("¡Check-in guardado!")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)

                    Text(viewModel.lastCelebratedVisitDescription)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.green.opacity(0.95), Color.cyan.opacity(0.95)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color.cyan.opacity(0.6), radius: 8)
            )
            .padding(.top, 4)

            Spacer()
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
