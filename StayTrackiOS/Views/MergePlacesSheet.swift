import SwiftUI
import StayTrackCore

/// Hoja para fusionar un lugar en otro conservando y actualizando el histórico de visitas.
struct MergePlacesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: iOSTrackingViewModel

    let sourcePlace: Place
    @State private var selectedTargetPlace: Place?

    var availableTargets: [Place] {
        viewModel.allPlaces.filter { $0.id != sourcePlace.id }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Lugar a fusionar (será eliminado):")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            Image(systemName: sourcePlace.categoria.defaultIcon)
                                .foregroundStyle(sourcePlace.categoria.accentColor)
                            Text(sourcePlace.nombre.isEmpty ? "Lugar sin nombre" : sourcePlace.nombre)
                                .font(.headline)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Selecciona el Lugar Destino") {
                    if availableTargets.isEmpty {
                        Text("No hay otros lugares disponibles para fusionar.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(availableTargets) { target in
                            HStack {
                                Image(systemName: target.categoria.defaultIcon)
                                    .foregroundStyle(target.categoria.accentColor)

                                Text(target.nombre.isEmpty ? "Lugar sin nombre" : target.nombre)
                                    .font(.body)

                                Spacer()

                                if selectedTargetPlace?.id == target.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.cyan)
                                        .fontWeight(.bold)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedTargetPlace = target
                            }
                        }
                    }
                }

                Section {
                    Text("Todas las visitas asociadas al lugar original se transferirán automáticamente al lugar destino y su histórico quedará actualizado.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Fusionar Lugares")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fusionar") {
                        if let target = selectedTargetPlace {
                            viewModel.mergePlaces(source: sourcePlace, into: target)
                            dismiss()
                        }
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(.orange)
                    .disabled(selectedTargetPlace == nil)
                }
            }
        }
    }
}
