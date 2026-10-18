import SwiftUI
import StayTrackCore

/// Pantalla con el catálogo completo de Lugares (Places): número de visitas, tiempo acumulado, renombrado y fusión.
struct PlacesListView: View {
    @ObservedObject var viewModel: iOSTrackingViewModel

    @State private var showCreateSheet: Bool = false
    @State private var editingPlace: Place?
    @State private var mergingSourcePlace: Place?

    var body: some View {
        NavigationStack {
            List {
                if viewModel.allPlaces.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text("No hay lugares registrados")
                            .font(.headline)
                        Text("Los lugares se crean automáticamente al cerrar estancias de más de 2 minutos o pulsando el botón +.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.allPlaces) { place in
                        placeRow(place: place)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let place = viewModel.allPlaces[index]
                            viewModel.deletePlace(place: place)
                        }
                    }
                }
            }
            .navigationTitle("Lugares")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.bold)
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                EditPlaceSheet(viewModel: viewModel, placeToEdit: nil)
            }
            .sheet(item: $editingPlace) { place in
                EditPlaceSheet(viewModel: viewModel, placeToEdit: place)
            }
            .sheet(item: $mergingSourcePlace) { source in
                MergePlacesSheet(viewModel: viewModel, sourcePlace: source)
            }
        }
    }

    private func placeRow(place: Place) -> some View {
        let visitsForPlace = viewModel.allVisits.filter { $0.placeId == place.id }
        let visitCount = visitsForPlace.count
        let totalTime = visitsForPlace.reduce(0) { $0 + $1.duration }
        let durationStr = StayTrackUtils.formatDuration(totalTime)

        return HStack(spacing: 12) {
            Image(systemName: place.categoria.defaultIcon)
                .font(.title3.bold())
                .foregroundStyle(place.categoria.accentColor)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(place.nombre.isEmpty ? "Lugar sin nombre" : place.nombre)
                        .font(.body.bold())
                        .foregroundStyle(.white)

                    if place.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }

                HStack(spacing: 6) {
                    Text(place.categoria.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("\(visitCount) \(visitCount == 1 ? "visita" : "visitas")")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(durationStr)
                        .font(.caption.bold())
                        .foregroundStyle(.cyan)
                }
            }

            Spacer()

            Menu {
                Button {
                    editingPlace = place
                } label: {
                    Label("Editar / Radio", systemImage: "pencil")
                }

                Button {
                    mergingSourcePlace = place
                } label: {
                    Label("Fusionar en otro lugar...", systemImage: "arrow.triangle.merge")
                }

                Button {
                    viewModel.toggleFavorite(place: place)
                } label: {
                    Label(place.isFavorite ? "Quitar de Favoritos" : "Marcar como Favorito", systemImage: place.isFavorite ? "star.slash" : "star.fill")
                }

                Button(role: .destructive) {
                    viewModel.deletePlace(place: place)
                } label: {
                    Label("Eliminar", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
        }
        .padding(.vertical, 4)
    }
}
