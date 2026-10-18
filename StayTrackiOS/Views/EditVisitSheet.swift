import SwiftUI
import StayTrackCore

/// Hoja para la edición manual de una estancia (corregir lugar, inicio/fin, dividir o eliminar).
struct EditVisitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: iOSTrackingViewModel

    let visit: Visit

    @State private var selectedPlace: Place?
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var isOngoing: Bool = false

    @State private var showSplitPicker: Bool = false
    @State private var splitDate: Date = Date()
    @State private var showDeleteConfirmation: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Lugar Asignado") {
                    Picker("Lugar", selection: $selectedPlace) {
                        Text("Sin lugar asignado").tag(nil as Place?)
                        ForEach(viewModel.allPlaces) { place in
                            HStack {
                                Image(systemName: place.categoria.defaultIcon)
                                    .foregroundStyle(place.categoria.accentColor)
                                Text(place.nombre.isEmpty ? "Lugar sin nombre" : place.nombre)
                            }
                            .tag(place as Place?)
                        }
                    }
                }

                Section("Horario de la Estancia") {
                    DatePicker("Hora de llegada", selection: $startDate)

                    Toggle("Estancia aún en curso", isOn: $isOngoing)
                        .tint(.cyan)

                    if !isOngoing {
                        DatePicker("Hora de salida", selection: $endDate)
                    }
                }

                Section("Dispositivo de Origen") {
                    HStack {
                        Image(systemName: visit.origen == .watch ? "applewatch" : "iphone")
                            .foregroundStyle(.cyan)
                        Text(visit.origen.displayName)
                        Spacer()
                        Text("Precisión: ±\(Int(visit.precision))m")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Acciones Avanzadas") {
                    Button {
                        splitDate = startDate.addingTimeInterval(visit.duration / 2.0)
                        showSplitPicker = true
                    } label: {
                        Label("Dividir Estancia en Dos", systemImage: "arrow.triangle.branch")
                            .foregroundStyle(.cyan)
                    }

                    if showSplitPicker {
                        VStack(alignment: .leading, spacing: 8) {
                            DatePicker("Punto de división", selection: $splitDate, in: startDate...endDate)
                                .datePickerStyle(.compact)

                            Button("Confirmar División") {
                                viewModel.splitVisit(visit: visit, splitDate: splitDate)
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.cyan)
                        }
                        .padding(.vertical, 4)
                    }

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Eliminar Estancia", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Editar Estancia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveChanges()
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(.cyan)
                }
            }
            .confirmationDialog("¿Eliminar esta estancia?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) {
                    viewModel.deleteVisit(visit: visit)
                    dismiss()
                }
            } message: {
                Text("Esta acción eliminará el registro de tiempo y recalculará los informes.")
            }
            .onAppear {
                selectedPlace = visit.place
                startDate = visit.inicio
                endDate = visit.fin ?? Date()
                isOngoing = visit.fin == nil
                splitDate = startDate.addingTimeInterval(max(60, visit.duration / 2.0))
            }
        }
    }

    private func saveChanges() {
        let finalEnd: Date? = isOngoing ? nil : endDate
        viewModel.editVisit(
            visit: visit,
            newPlace: selectedPlace,
            newStart: startDate,
            newEnd: finalEnd
        )
    }
}
