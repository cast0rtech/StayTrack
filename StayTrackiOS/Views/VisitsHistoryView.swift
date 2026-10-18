import SwiftUI
import StayTrackCore

/// Pantalla con el historial completo de estancias registradas (Visits) y edición manual.
struct VisitsHistoryView: View {
    @ObservedObject var viewModel: iOSTrackingViewModel
    @State private var editingVisit: Visit?

    var groupedVisits: [(dateString: String, visits: [Visit])] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let grouped = Dictionary(grouping: viewModel.allVisits) { visit -> String in
            if calendar.isDateInToday(visit.inicio) {
                return "Hoy"
            } else if calendar.isDateInYesterday(visit.inicio) {
                return "Ayer"
            } else {
                return formatter.string(from: visit.inicio)
            }
        }

        // Ordenar las secciones cronológicamente por la visita más reciente
        return grouped.map { (dateString: $0.key, visits: $0.value) }
            .sorted { first, second in
                let d1 = first.visits.first?.inicio ?? Date.distantPast
                let d2 = second.visits.first?.inicio ?? Date.distantPast
                return d1 > d2
            }
    }

    var body: some View {
        NavigationStack {
            List {
                if viewModel.allVisits.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text("No hay estancias registradas")
                            .font(.headline)
                        Text("Las estancias se registran automáticamente cuando permaneces más de 2 minutos dentro del radio de una zona.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(groupedVisits, id: \.dateString) { group in
                        Section(group.dateString) {
                            ForEach(group.visits) { visit in
                                visitRow(visit: visit)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Estancias")
            .sheet(item: $editingVisit) { visit in
                EditVisitSheet(viewModel: viewModel, visit: visit)
            }
        }
    }

    private func visitRow(visit: Visit) -> some View {
        Button {
            editingVisit = visit
        } label: {
            HStack(spacing: 12) {
                // Icono de categoría
                Image(systemName: visit.place?.categoria.defaultIcon ?? "mappin.and.ellipse")
                    .font(.title3.bold())
                    .foregroundStyle(visit.place?.categoria.accentColor ?? .cyan)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(visit.place?.nombre.isEmpty == false ? visit.place!.nombre : "Zona detectada")
                            .font(.body.bold())
                            .foregroundStyle(.white)

                        if visit.place?.isFavorite == true {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                        }
                    }

                    HStack(spacing: 6) {
                        Text(StayTrackUtils.formatInterval(start: visit.inicio, end: visit.fin))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        // Origen del dispositivo
                        HStack(spacing: 3) {
                            Image(systemName: visit.origen == .watch ? "applewatch" : "iphone")
                                .font(.system(size: 10))
                            Text(visit.origen.displayName)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(visit.origen == .watch ? .purple : .cyan)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(StayTrackUtils.formatDuration(visit.duration))
                        .font(.subheadline.bold())
                        .foregroundStyle(.cyan)

                    if visit.isOngoing {
                        Text("En curso")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(.green)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
