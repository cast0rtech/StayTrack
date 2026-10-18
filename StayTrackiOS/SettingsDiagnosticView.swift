import SwiftUI
import StayTrackCore

/// Pantalla de configuración, estado de hardware y diagnóstico de plataforma.
/// Expone las decisiones de arquitectura, estado de sensores y checklist de validación física.
public struct SettingsDiagnosticView: View {
    @ObservedObject var viewModel: iOSTrackingViewModel
    @State private var defaultRadius: Double = 75.0
    @State private var showingArchitectureReport: Bool = false

    public init(viewModel: iOSTrackingViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Estado de Conectividad con Apple Watch
                    watchConnectivityCard

                    // Sensor de Movimiento (CoreMotion)
                    coreMotionCard

                    // Configuración de Motor de Detección
                    detectionEngineCard

                    // Limitaciones y Validación en Dispositivo Físico
                    physicalValidationCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.06, blue: 0.11), Color(red: 0.02, green: 0.03, blue: 0.06)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Ajustes")
            .sheet(isPresented: $showingArchitectureReport) {
                NavigationStack {
                    ScrollView {
                        Text(PlatformLimitations.architecturalReport)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white)
                            .padding()
                    }
                    .background(Color.black.ignoresSafeArea())
                    .navigationTitle("Informe Técnico")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Cerrar") {
                                showingArchitectureReport = false
                            }
                        }
                    }
                }
            }
        }
    }

    private var watchConnectivityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "applewatch.side.right")
                    .font(.system(size: 18))
                    .foregroundColor(.cyan)

                Text("WatchConnectivity (WCSession)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                #if canImport(WatchConnectivity)
                Text(WatchConnectivityManager.shared.isReachable ? "EN VIVO" : "ENCOLADO")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(WatchConnectivityManager.shared.isReachable ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                    .foregroundColor(WatchConnectivityManager.shared.isReachable ? .green : .orange)
                    .clipShape(Capsule())
                #endif
            }

            VStack(spacing: 6) {
                #if canImport(WatchConnectivity)
                statusRow(title: "Emparejado con Apple Watch", value: WatchConnectivityManager.shared.isPaired ? "Sí" : "No")
                statusRow(title: "App Watch instalada", value: WatchConnectivityManager.shared.isWatchAppInstalled ? "Sí" : "No")
                statusRow(title: "Canal bidireccional activo", value: WatchConnectivityManager.shared.isReachable ? "Conectado" : "Esperando conexión")
                #endif
                statusRow(title: "Última sincronización", value: viewModel.lastSyncDate?.formatted(date: .omitted, time: .standard) ?? "Pendiente")
            }

            Button {
                viewModel.syncWithWatch()
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Forzar Sincronización Inmediata")
                }
                .font(.system(size: 13, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.cyan.opacity(0.2))
                .foregroundColor(.cyan)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }

    private var coreMotionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.walk.motion")
                    .font(.system(size: 18))
                    .foregroundColor(.purple)

                Text("CoreMotion (Detección de Movimiento)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)

                Spacer()
            }

            VStack(spacing: 6) {
                statusRow(title: "Coprocesador M-series", value: viewModel.motionManager.isMotionAvailable ? "Disponible" : "Simulador / No disp.")
                statusRow(title: "Estado físico detectado", value: viewModel.motionManager.currentActivityDescription)
                statusRow(title: "Resolución de conflictos", value: "El dispositivo en movimiento prevalece sobre el estático")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }

    private var detectionEngineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gearshape.2.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.cyan)

                Text("Parámetros del Motor de Check-in")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Radio por defecto de zonas ancla:")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)

                Picker("Radio por defecto", selection: $defaultRadius) {
                    Text("50 m").tag(50.0)
                    Text("75 m (Defecto)").tag(75.0)
                    Text("100 m").tag(100.0)
                }
                .pickerStyle(.segmented)
                .onChange(of: defaultRadius) { _, newRad in
                    viewModel.locationTracker.detector.configuration.detectionRadius = newRad
                }
            }

            VStack(spacing: 6) {
                statusRow(title: "Umbral mínimo de check-in", value: "2 minutos (> 120 s)")
                statusRow(title: "Salida sostenida requerida", value: "60 s fuera del radio")
                statusRow(title: "Filtro de precisión GPS", value: "Descartar si > 50 metros")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }

    private var physicalValidationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.yellow)

                Text("Limitaciones y Validación Física")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }

            Text("El simulador de macOS no emula el acelerómetro ni el coprocesador CoreMotion. Para certificar el proyecto, valida en dispositivos físicos:")
                .font(.system(size: 12))
                .foregroundColor(.gray)

            VStack(alignment: .leading, spacing: 4) {
                checklistRow(text: "Dejar iPhone sobre la mesa y salir con el Watch a caminar.")
                checklistRow(text: "Comprobar que la estancia del iPhone se recorta en favor del Watch.")
                checklistRow(text: "Verificar indicador dinámico de ubicación en segundo plano.")
            }

            Button {
                showingArchitectureReport = true
            } label: {
                Text("Ver Informe de Decisiones de Arquitectura")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.cyan)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.yellow.opacity(0.2), lineWidth: 1))
        )
    }

    private func statusRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    private func checklistRow(text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundColor(.cyan)
                .padding(.top, 2)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.85))
        }
    }
}
