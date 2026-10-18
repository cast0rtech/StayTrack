import SwiftUI
import StayTrackCore

/// Hoja para crear o editar un lugar físico en iOS.
struct EditPlaceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: iOSTrackingViewModel

    var placeToEdit: Place?

    @State private var name: String = ""
    @State private var selectedCategory: PlaceCategory = .otro
    @State private var radius: Double = 75.0
    @State private var isFavorite: Bool = false
    @State private var customRadiusText: String = "75"
    @State private var useCustomRadius: Bool = false

    private let presetRadii: [Double] = [50.0, 75.0, 100.0]

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos del Lugar") {
                    TextField("Nombre del lugar (ej. Casa, Oficina)", text: $name)
                        .font(.body)

                    Toggle("Marcar como Favorito", isOn: $isFavorite)
                        .tint(.cyan)
                }

                Section("Categoría") {
                    Picker("Categoría", selection: $selectedCategory) {
                        ForEach(PlaceCategory.allCases) { cat in
                            HStack {
                                Image(systemName: cat.defaultIcon)
                                    .foregroundStyle(cat.accentColor)
                                Text(cat.displayName)
                            }
                            .tag(cat)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section("Radio de Zona") {
                    Picker("Radio", selection: $useCustomRadius) {
                        Text("Predefinido").tag(false)
                        Text("Personalizado").tag(true)
                    }
                    .pickerStyle(.segmented)

                    if !useCustomRadius {
                        HStack {
                            ForEach(presetRadii, id: \.self) { r in
                                Button {
                                    radius = r
                                } label: {
                                    Text("\(Int(r)) m")
                                        .font(.subheadline.bold())
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(radius == r ? Color.cyan.opacity(0.3) : Color.white.opacity(0.08))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(radius == r ? Color.cyan : Color.clear, lineWidth: 1.5)
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        HStack {
                            Text("Radio en metros:")
                            Spacer()
                            TextField("Metros", text: $customRadiusText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                    }
                }
            }
            .navigationTitle(placeToEdit == nil ? "Nuevo Lugar" : "Editar Lugar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        savePlace()
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(.cyan)
                }
            }
            .onAppear {
                if let p = placeToEdit {
                    name = p.nombre
                    selectedCategory = p.categoria
                    radius = p.radio
                    isFavorite = p.isFavorite
                    if !presetRadii.contains(p.radio) {
                        useCustomRadius = true
                        customRadiusText = "\(Int(p.radio))"
                    }
                }
            }
        }
    }

    private func savePlace() {
        let finalRadius: Double
        if useCustomRadius, let parsed = Double(customRadiusText), parsed > 10 {
            finalRadius = parsed
        } else {
            finalRadius = radius
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmedName.isEmpty ? selectedCategory.displayName : trimmedName

        if let existing = placeToEdit {
            viewModel.editPlace(
                place: existing,
                name: finalName,
                category: selectedCategory,
                radius: finalRadius,
                isFavorite: isFavorite
            )
        } else {
            let coord = viewModel.lastKnownLocation ?? Coordinate(latitude: 40.4168, longitude: -3.7038)
            viewModel.createPlace(
                name: finalName,
                category: selectedCategory,
                radius: finalRadius,
                isFavorite: isFavorite,
                coordinate: coord
            )
        }
    }
}
