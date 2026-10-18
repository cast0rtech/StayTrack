import SwiftUI
import StayTrackCore

/// Pantalla dedicada a la gestión de Lugares Favoritos en iOS.
struct FavoritesView: View {
    @ObservedObject var viewModel: iOSTrackingViewModel
    @State private var showCreateSheet: Bool = false
    @State private var editingPlace: Place?
    @State private var showCurrentLocationAlert: Bool = false
    @State private var currentLocationName: String = "Mi Ubicación Actual"
    @State private var currentLocationCategory: PlaceCategory = .casa

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Botón destacado: "Añadir lugar actual como Favorito"
                    Button {
                        showCurrentLocationAlert = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "location.fill")
                                .font(.title3)
                                .foregroundStyle(.white)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Añadir Lugar Actual")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("Convierte tus coordenadas actuales en favorito")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.8))
                            }

                            Spacer()

                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                        }
                        .padding(14)
                        .background(
                            LinearGradient(
                                colors: [.cyan, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                        .shadow(color: .cyan.opacity(0.3), radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    // Lista de Favoritos
                    if viewModel.favoritePlaces.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "star.slash")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("Aún no tienes lugares favoritos")
                                .font(.headline)
                            Text("Los favoritos tienen prioridad sobre lugares sin nombre al asignar estancias.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .padding(.horizontal)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.favoritePlaces) { place in
                                favoriteCard(place: place)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .navigationTitle("Favoritos")
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
            .alert("Añadir Ubicación Actual", isPresented: $showCurrentLocationAlert) {
                TextField("Nombre del lugar", text: $currentLocationName)
                Button("Guardar", action: {
                    viewModel.addCurrentLocationAsFavorite(
                        name: currentLocationName,
                        category: currentLocationCategory,
                        radius: 75.0
                    )
                })
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Se registrará la posición GPS actual como un nuevo punto de anclaje favorito.")
            }
        }
    }

    private func favoriteCard(place: Place) -> some View {
        HStack(spacing: 14) {
            // Icono con color de categoría
            Image(systemName: place.categoria.defaultIcon)
                .font(.title2.bold())
                .foregroundStyle(place.categoria.accentColor)
                .frame(width: 48, height: 48)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(place.nombre.isEmpty ? "Favorito sin nombre" : place.nombre)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }

                HStack(spacing: 6) {
                    Text(place.categoria.displayName)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("Radio \(Int(place.radio)) m")
                        .font(.caption)
                        .foregroundStyle(.cyan)
                }
            }

            Spacer()

            Menu {
                Button {
                    editingPlace = place
                } label: {
                    Label("Editar", systemImage: "pencil")
                }

                Button {
                    viewModel.toggleFavorite(place: place)
                } label: {
                    Label("Quitar de Favoritos", systemImage: "star.slash")
                }

                Button(role: .destructive) {
                    viewModel.deletePlace(place: place)
                } label: {
                    Label("Eliminar", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}
