import SwiftUI
import CoreLocation
import StayTrackCore

/// Hoja modal para crear o editar un Lugar (Place).
/// Permite configurar nombre, categoría, icono, radio de detección y estado de favorito.
public struct EditPlaceSheet: View {
    @Environment(\.dismiss) private var dismiss

    var placeToEdit: Place?
    var onSave: (String, PlaceCategory, String, Bool, Double, Double, Double) -> Void

    @State private var name: String
    @State private var category: PlaceCategory
    @State private var icon: String
    @State private var isFavorite: Bool
    @State private var radius: Double
    @State private var latitudeString: String
    @State private var longitudeString: String

    private let availableIcons = [
        "house.fill", "briefcase.fill", "figure.run", "cross.case.fill",
        "cart.fill", "graduationcap.fill", "fork.knife", "cup.and.saucer.fill",
        "book.fill", "airplane", "car.fill", "mappin.and.ellipse"
    ]

    public init(
        placeToEdit: Place? = nil,
        initialCoordinate: CLLocationCoordinate2D? = nil,
        onSave: @escaping (String, PlaceCategory, String, Bool, Double, Double, Double) -> Void
    ) {
        self.placeToEdit = placeToEdit
        self.onSave = onSave

        _name = State(initialValue: placeToEdit?.name ?? "")
        _category = State(initialValue: placeToEdit?.category ?? .home)
        _icon = State(initialValue: placeToEdit?.icon ?? "house.fill")
        _isFavorite = State(initialValue: placeToEdit?.isFavorite ?? false)
        _radius = State(initialValue: placeToEdit?.radius ?? 75.0)

        let lat = placeToEdit?.latitude ?? initialCoordinate?.latitude ?? 40.4168
        let lon = placeToEdit?.longitude ?? initialCoordinate?.longitude ?? -3.7038
        _latitudeString = State(initialValue: String(format: "%.6f", lat))
        _longitudeString = State(initialValue: String(format: "%.6f", lon))
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Información Básica")) {
                    TextField("Nombre del lugar (ej. Casa, Gimnasio)", text: $name)
                        .font(.system(size: 16, weight: .medium))

                    Picker("Categoría", selection: $category) {
                        ForEach(PlaceCategory.allCases) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                    .onChange(of: category) { _, newCat in
                        if placeToEdit == nil {
                            icon = newCat.defaultIcon
                        }
                    }

                    Toggle(isOn: $isFavorite) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Lugar Favorito")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Los favoritos tienen prioridad sobre lugares genéricos al asignar estancias.")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                    }
                    .tint(.pink)
                }

                Section(header: Text("Icono Personalizado")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(availableIcons, id: \.self) { sym in
                                Button {
                                    icon = sym
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(icon == sym ? Color.cyan.opacity(0.3) : Color.white.opacity(0.08))
                                            .frame(width: 44, height: 44)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(icon == sym ? Color.cyan : Color.clear, lineWidth: 1.5)
                                            )

                                        Image(systemName: sym)
                                            .font(.system(size: 20))
                                            .foregroundColor(icon == sym ? .cyan : .white)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section(header: Text("Radio de Detección")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Radio: \(Int(radius)) metros")
                                .font(.system(size: 14, weight: .bold))
                            Spacer()
                        }

                        Picker("Radio", selection: $radius) {
                            Text("50 m (Estrecho)").tag(50.0)
                            Text("75 m (Por defecto)").tag(75.0)
                            Text("100 m (Amplio)").tag(100.0)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section(header: Text("Coordenadas Geográficas")) {
                    HStack {
                        Text("Latitud")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        Spacer()
                        TextField("Latitud", text: $latitudeString)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numbersAndPunctuation)
                    }

                    HStack {
                        Text("Longitud")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        Spacer()
                        TextField("Longitud", text: $longitudeString)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numbersAndPunctuation)
                    }
                }
            }
            .navigationTitle(placeToEdit == nil ? "Nuevo Lugar" : "Editar Lugar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveAction()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveAction() {
        let lat = Double(latitudeString.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let lon = Double(longitudeString.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        onSave(name, category, icon, isFavorite, radius, lat, lon)
        dismiss()
    }
}
