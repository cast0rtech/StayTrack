import SwiftUI
import StayTrackCore

/// Pantalla de ajustes y diagnósticos técnicos en Apple Watch.
struct WatchSettingsView: View {
    @ObservedObject var viewModel: WatchTrackingViewModel
    private let radii: [Double] = [50.0, 75.0, 100.0]

    var body: some View {
        List {
            Section("Radio de Zona") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Configura el radio de anclaje para crear un check-in tras > 2 minutos:")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        ForEach(radii, id: \.self) { r in
                            Button {
                                viewModel.detectionRadius = r
                            } label: {
                                Text("\(Int(r)) m")
                                    .font(.system(size: 12, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(viewModel.detectionRadius == r ? Color.cyan.opacity(0.3) : Color.white.opacity(0.08))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(viewModel.detectionRadius == r ? Color.cyan : Color.clear, lineWidth: 1)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Segundo Plano") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Sesión")
                            .font(.system(size: 11, weight: .medium))
                        Spacer()
                        Text(viewModel.backgroundSessionManager.isSessionRunning ? "Activa" : "Inactiva")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(viewModel.backgroundSessionManager.isSessionRunning ? .green : .orange)
                    }

                    Text(viewModel.backgroundSessionManager.lastSessionStateDescription)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }

            Section("Sincronización iPhone") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Enlace")
                            .font(.system(size: 11, weight: .medium))
                        Spacer()
                        Text(viewModel.connectivityManager.isReachable ? "Conectado" : "En cola (Offline)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(viewModel.connectivityManager.isReachable ? .green : .cyan)
                    }

                    Text("Los datos se guardan localmente en SwiftData y se transfieren al iPhone automáticamente cuando esté disponible.")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }

            Section("Limitaciones Técnicas") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("• watchOS suspende procesos en segundo plano para proteger la batería de 250 mAh.")
                    Text("• Las lecturas satelitales se agrupan (coalescing) con posibles retrasos de varios minutos.")
                    Text("• El seguimiento de movimiento real requiere validación en un reloj físico.")
                }
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Ajustes")
    }
}
