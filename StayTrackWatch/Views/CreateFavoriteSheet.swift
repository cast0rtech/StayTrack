import SwiftUI
import StayTrackCore

/// Hoja para crear rápidamente un lugar favorito con un toque desde la muñeca.
struct CreateFavoriteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: WatchTrackingViewModel

    @State private var placeName: String = ""
    @State private var selectedCategory: PlaceCategory = .casa
    @State private var selectedRadius: Double = 75.0

    private let categories: [PlaceCategory] = [.casa, .trabajo, .entrenamiento, .medico, .otro]
    private let radii: [Double] = [50.0, 75.0, 100.0]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Nuevo Favorito")
                    .font(.headline)
                    .foregroundStyle(.cyan)
                    .padding(.top, 4)

                // Selector de Categoría con iconos y acentos vibrantes
                VStack(alignment: .leading, spacing: 6) {
                    Text("CATEGORÍA")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories, id: \.self) { cat in
                                Button {
                                    selectedCategory = cat
                                    if placeName.isEmpty || categories.map(\.displayName).contains(placeName) {
                                        placeName = cat.displayName
                                    }
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: cat.defaultIcon)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(cat.accentColor)

                                        Text(cat.displayName)
                                            .font(.system(size: 9, weight: .medium))
                                            .lineLimit(1)
                                    }
                                    .frame(width: 58, height: 48)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(selectedCategory == cat ? Color.cyan.opacity(0.25) : Color.white.opacity(0.08))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(selectedCategory == cat ? Color.cyan : Color.clear, lineWidth: 1.5)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Nombre del Lugar
                VStack(alignment: .leading, spacing: 4) {
                    Text("NOMBRE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)

                    TextField("Nombre del lugar", text: $placeName)
                        .font(.system(size: 13, weight: .semibold))
                        .textInputAutocapitalization(.words)
                }

                // Radio de la Zona
                VStack(alignment: .leading, spacing: 4) {
                    Text("RADIO DE ZONA")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        ForEach(radii, id: \.self) { r in
                            Button {
                                selectedRadius = r
                            } label: {
                                Text("\(Int(r)) m")
                                    .font(.system(size: 11, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedRadius == r ? Color.purple.opacity(0.3) : Color.white.opacity(0.08))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(selectedRadius == r ? Color.purple : Color.clear, lineWidth: 1)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Botón Guardar
                Button {
                    let finalName = placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? selectedCategory.displayName
                        : placeName

                    viewModel.createFavoriteFromCurrent(
                        name: finalName,
                        category: selectedCategory,
                        icon: selectedCategory.defaultIcon,
                        radius: selectedRadius
                    )
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text("Guardar Favorito")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [.cyan, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
        .onAppear {
            if placeName.isEmpty {
                placeName = selectedCategory.displayName
            }
        }
    }
}
