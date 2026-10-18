import SwiftUI
import SwiftData
import StayTrackCore

/// Pantalla principal para watchOS con diseño futurista dark-mode,
/// acentos cian/morado, texto grande y baja densidad de información por pantalla.
public struct WatchContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = WatchTrackingViewModel()
    @State private var selectedTab: Int = 0
    @State private var pulseAnimation: Bool = false

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Estado y Estancia Activa
            ActiveStayWatchTab(viewModel: viewModel, pulseAnimation: $pulseAnimation)
                .tag(0)

            // Tab 2: Historial Reciente
            RecentVisitsWatchTab(viewModel: viewModel)
                .tag(1)

            // Tab 3: Lugares Registrados
            PlacesWatchTab(viewModel: viewModel)
                .tag(2)

            // Tab 4: Conectividad y Ajustes
            SyncSettingsWatchTab(viewModel: viewModel)
                .tag(3)
        }
        .tabViewStyle(.page)
        .onAppear {
            viewModel.configure(modelContext: modelContext)
            pulseAnimation = true
        }
    }
}

// MARK: - Tab 1: Estancia Activa y Radar

struct ActiveStayWatchTab: View {
    @ObservedObject var viewModel: WatchTrackingViewModel
    @Binding var pulseAnimation: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Indicador de estado y radar
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.isTrackingActive ? Color.cyan : Color.gray)
                        .frame(width: 8, height: 8)
                        .scaleEffect(pulseAnimation && viewModel.isTrackingActive ? 1.4 : 1.0)
                        .animation(
                            viewModel.isTrackingActive ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true) : .default,
                            value: pulseAnimation
                        )

                    Text(viewModel.isTrackingActive ? "AUTÓNOMO" : "PAUSADO")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(.cyan)

                    Spacer()

                    Image(systemName: "applewatch")
                        .font(.system(size: 11))
                        .foregroundColor(.purple)
                }
                .padding(.horizontal, 4)

                // Lugar actual
                if let place = viewModel.currentPlace {
                    VStack(spacing: 2) {
                        Image(systemName: place.icon)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.cyan, Color.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .padding(.top, 4)

                        Text(place.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Text(place.category.displayName.uppercased())
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.cyan.opacity(0.2))
                            .clipShape(Capsule())
                    }
                } else if viewModel.activeVisit != nil {
                    VStack(spacing: 2) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.cyan)

                        Text("Punto Ancla")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)

                        Text("Lugar sin nombrar")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "figure.walk.motion")
                            .font(.system(size: 22))
                            .foregroundColor(.cyan.opacity(0.8))

                        Text("En movimiento")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 6)
                }

                // Cronómetro de estancia destacada
                VStack(spacing: 1) {
                    Text(viewModel.elapsedTimeString)
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .cyan],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    Text(viewModel.activeVisit != nil ? "TIEMPO EN LUGAR" : "BUSCANDO CHECK-IN")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.cyan.opacity(0.25), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Tab 2: Historial Reciente

struct RecentVisitsWatchTab: View {
    @ObservedObject var viewModel: WatchTrackingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Estancias")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundColor(.cyan)
                .padding(.horizontal, 4)

            if viewModel.recentVisits.isEmpty {
                VStack(spacing: 4) {
                    Spacer()
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                    Text("Sin visitas aún")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(viewModel.recentVisits.prefix(6), id: \.id) { visit in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(visit.place?.name ?? "Punto Ancla")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)

                                Spacer()

                                Text(formatDuration(visit.duration))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.cyan)
                            }

                            HStack {
                                Text(visit.arrivalDate.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: 9))
                                    .foregroundColor(.gray)

                                Spacer()

                                if visit.isOngoing {
                                    Text("ACTIVA")
                                        .font(.system(size: 8, weight: .black))
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.05))
                        )
                    }
                }
                .listStyle(.carousel)
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(max(1, minutes))m"
        }
    }
}

// MARK: - Tab 3: Lugares Registrados

struct PlacesWatchTab: View {
    @ObservedObject var viewModel: WatchTrackingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Lugares (\(viewModel.places.count))")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundColor(.purple)
                .padding(.horizontal, 4)

            if viewModel.places.isEmpty {
                VStack(spacing: 4) {
                    Spacer()
                    Image(systemName: "mappin.slash")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                    Text("Configura lugares desde iPhone")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(viewModel.places, id: \.id) { place in
                        HStack(spacing: 8) {
                            Image(systemName: place.icon)
                                .font(.system(size: 14))
                                .foregroundColor(place.isFavorite ? .pink : .cyan)

                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 4) {
                                    Text(place.name)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)

                                    if place.isFavorite {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 8))
                                            .foregroundColor(.yellow)
                                    }
                                }

                                Text("\(Int(place.radius))m radio")
                                    .font(.system(size: 9))
                                    .foregroundColor(.gray)
                            }
                        }
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.05))
                        )
                    }
                }
                .listStyle(.carousel)
            }
        }
    }
}

// MARK: - Tab 4: Conectividad y Ajustes

struct SyncSettingsWatchTab: View {
    @ObservedObject var viewModel: WatchTrackingViewModel
    @State private var showingRadiusPicker = false

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("Conectividad")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundColor(.cyan)

                Button {
                    viewModel.syncWithIphone()
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12, weight: .bold))
                        Text("Sincronizar")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .tint(.cyan)

                Text(viewModel.lastSyncMessage)
                    .font(.system(size: 9))
                    .foregroundColor(.gray)

                Divider()
                    .padding(.vertical, 2)

                // Radio de detección configurable
                VStack(alignment: .leading, spacing: 2) {
                    Text("Radio Zona: \(Int(viewModel.detectionRadius))m")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)

                    HStack {
                        ForEach([50.0, 75.0, 100.0], id: \.self) { r in
                            Button("\(Int(r))m") {
                                viewModel.detectionRadius = r
                                viewModel.locationTracker.detector.configuration.detectionRadius = r
                            }
                            .buttonStyle(.bordered)
                            .tint(viewModel.detectionRadius == r ? .cyan : .gray)
                            .font(.system(size: 9, weight: .bold))
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}
