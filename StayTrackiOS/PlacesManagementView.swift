import SwiftUI
import MapKit
import StayTrackCore

/// Pantalla de gestión de Lugares (Places).
/// Ofrece un mapa interactivo con pines y radios de cobertura,
/// lista de lugares configurados, conmutador de favoritos y modal de edición.
public struct PlacesManagementView: View {
    @ObservedObject var viewModel: iOSTrackingViewModel
    @State private var showingAddSheet: Bool = false
    @State private var placeToEdit: Place?
    @State private var mapPosition: MapCameraPosition = .automatic

    public init(viewModel: iOSTrackingViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mapa interactivo superior con los lugares
                mapSection
                    .frame(height: 240)

                // Lista de lugares guardados
                placesList
            }
            .background(
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.06, blue: 0.11), Color(red: 0.02, green: 0.03, blue: 0.06)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Lugares")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.cyan)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                EditPlaceSheet(initialCoordinate: viewModel.locationTracker.lastLocation?.coordinate) { name, cat, icon, fav, rad, lat, lon in
                    viewModel.addPlace(name: name, category: cat, icon: icon, isFavorite: fav, latitude: lat, longitude: lon, radius: rad)
                }
            }
            .sheet(item: $placeToEdit) { place in
                EditPlaceSheet(placeToEdit: place) { name, cat, icon, fav, rad, _, _ in
                    viewModel.updatePlace(place: place, name: name, category: cat, icon: icon, isFavorite: fav, radius: rad)
                }
            }
        }
    }

    private var mapSection: some View {
        Map(position: $mapPosition) {
            ForEach(viewModel.places, id: \.id) { place in
                let coordinate = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)

                Annotation(place.name, coordinate: coordinate) {
                    ZStack {
                        Circle()
                            .fill(place.isFavorite ? Color.pink : Color.cyan)
                            .frame(width: 34, height: 34)
                            .shadow(color: place.isFavorite ? .pink : .cyan, radius: 8)

                        Image(systemName: place.icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                MapCircle(center: coordinate, radius: place.radius)
                    .foregroundStyle(Color.cyan.opacity(0.18))
                    .stroke(Color.cyan.opacity(0.7), lineWidth: 1.5)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
    }

    private var placesList: some View {
        List {
            ForEach(viewModel.places, id: \.id) { place in
                placeCard(place)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.deletePlace(place)
                        } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            placeToEdit = place
                        } label: {
                            Label("Editar", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func placeCard(_ place: Place) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: place.category.accentHex).opacity(0.2))
                    .frame(width: 46, height: 46)

                Image(systemName: place.icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: place.category.accentHex))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(place.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)

                    if place.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.yellow)
                    }

                    Spacer()

                    Text("\(Int(place.radius))m")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.cyan.opacity(0.2))
                        .foregroundColor(.cyan)
                        .clipShape(Capsule())
                }

                HStack {
                    Text(place.category.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)

                    Spacer()

                    let visitCount = place.visits?.count ?? 0
                    Text("\(visitCount) estancias")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }

            Button {
                placeToEdit = place
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            place.isFavorite ? Color.pink.opacity(0.4) : Color.white.opacity(0.08),
                            lineWidth: 1
                        )
                )
        )
    }
}
