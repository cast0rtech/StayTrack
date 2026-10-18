import SwiftUI
import StayTrackCore

/// Vista de historial cronológico de estancias registradas.
/// Destaca el dispositivo de origen (Apple Watch con prioridad frente a iPhone),
/// duración, fechas y detección de movimiento.
public struct VisitsHistoryView: View {
    @ObservedObject var viewModel: iOSTrackingViewModel
    @State private var filterCategory: PlaceCategory?

    public init(viewModel: iOSTrackingViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filtro rápido por categoría
                categoryFilterBar

                if filteredVisits.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(filteredVisits, id: \.id) { visit in
                            visitCard(visit)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        viewModel.deleteVisit(visit)
                                    } label: {
                                        Label("Eliminar", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.06, blue: 0.11), Color(red: 0.02, green: 0.03, blue: 0.06)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Historial")
        }
    }

    private var filteredVisits: [Visit] {
        if let cat = filterCategory {
            return viewModel.visits.filter { $0.place?.category == cat }
        }
        return viewModel.visits
    }

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    filterCategory = nil
                } label: {
                    Text("Todos")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(filterCategory == nil ? Color.cyan : Color.white.opacity(0.08))
                        .foregroundColor(filterCategory == nil ? .black : .white)
                        .clipShape(Capsule())
                }

                ForEach(PlaceCategory.allCases) { cat in
                    Button {
                        filterCategory = (filterCategory == cat) ? nil : cat
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: cat.defaultIcon)
                                .font(.system(size: 11))
                            Text(cat.displayName)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(filterCategory == cat ? Color(hex: cat.accentHex) : Color.white.opacity(0.08))
                        .foregroundColor(filterCategory == cat ? .black : .white)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func visitCard(_ visit: Visit) -> some View {
        let isWatch = visit.deviceSource == .watch
        let category = visit.place?.category ?? .other

        return HStack(spacing: 14) {
            // Icono de lugar o ancla
            ZStack {
                Circle()
                    .fill(Color(hex: category.accentHex).opacity(0.18))
                    .frame(width: 44, height: 44)

                Image(systemName: visit.place?.icon ?? "mappin.and.ellipse")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: category.accentHex))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(visit.place?.name ?? "Punto Ancla")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()

                    // Dispositivo origen
                    HStack(spacing: 4) {
                        Image(systemName: isWatch ? "applewatch" : "iphone")
                            .font(.system(size: 11))
                        Text(isWatch ? "Watch" : "iPhone")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(isWatch ? Color.purple.opacity(0.3) : Color.blue.opacity(0.3))
                    .foregroundColor(isWatch ? .purple : .cyan)
                    .clipShape(Capsule())
                }

                HStack(spacing: 8) {
                    Text(visit.arrivalDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)

                    Text("•")
                        .foregroundColor(.gray)

                    Text(formatDuration(visit.duration))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)

                    if visit.isOngoing {
                        Text("EN CURSO")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .clipShape(Capsule())
                    }

                    if visit.isMovingDetected {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 11))
                            .foregroundColor(.yellow.opacity(0.9))
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    isWatch ? Color.purple.opacity(0.35) : Color.cyan.opacity(0.3),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "clock.badge.xmark")
                .font(.system(size: 44))
                .foregroundColor(.gray)

            Text("No hay visitas para mostrar")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Text("Las estancias superiores a 2 minutos se registrarán automáticamente aquí.")
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
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
