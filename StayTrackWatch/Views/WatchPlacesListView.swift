import SwiftUI
import StayTrackCore

/// Lista de lugares guardados en el Apple Watch con opciones para renombrar y alternar favoritos.
struct WatchPlacesListView: View {
    @ObservedObject var viewModel: WatchTrackingViewModel
    @State private var editingPlace: Place?
    @State private var editName: String = ""

    var body: some View {
        List {
            if viewModel.allPlaces.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "mappin.slash")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No hay lugares registrados aún")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.allPlaces) { (place: Place) in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: place.categoria.defaultIcon)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(place.categoria.accentColor)

                            Text(place.nombre.isEmpty ? "Lugar sin nombre" : place.nombre)
                                .font(.system(size: 13, weight: .bold))
                                .lineLimit(1)

                            Spacer()

                            Button {
                                viewModel.toggleFavorite(place: place)
                            } label: {
                                Image(systemName: place.isFavorite ? "star.fill" : "star")
                                    .font(.system(size: 13))
                                    .foregroundStyle(place.isFavorite ? .yellow : .secondary)
                            }
                            .buttonStyle(.plain)
                        }

                        HStack {
                            Text(place.categoria.displayName)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)

                            Text("•")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)

                            Text("\(Int(place.radio)) m")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.cyan)

                            Spacer()

                            Button {
                                editingPlace = place
                                editName = place.nombre
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.cyan)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Lugares")
        .sheet(item: $editingPlace) { place in
            VStack(spacing: 12) {
                Text("Renombrar Lugar")
                    .font(.headline)
                    .foregroundStyle(.cyan)

                TextField("Nombre", text: $editName)
                    .font(.system(size: 13, weight: .semibold))

                Button {
                    let finalName = editName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !finalName.isEmpty {
                        viewModel.renamePlace(place: place, newName: finalName)
                    }
                    editingPlace = nil
                } label: {
                    Text("Guardar")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.cyan, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
    }
}
